defmodule Sensory.STDPCoordinator do
  @moduledoc """
  Correlates operator-induced nociception with recent motor traces using
  a monotonic eligibility window and emits typed STDP prediction errors.
  """

  use GenServer
  require Logger

  @default_lambda 0.1
  @default_subject "operator.nociception"
  @default_retry_delay_ms 50
  @max_retry_attempts 3

  # Epoch-gated tracking
  @epoch_close_subject "endocrine.epoch_close"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def register_trace(trace) when is_map(trace) do
    GenServer.cast(__MODULE__, {:register_trace, trace})
  end

  def runtime_state(server \\ __MODULE__) do
    GenServer.call(server, :runtime_state)
  end

  @impl true
  def init(opts) do
    subject = Keyword.get(opts, :subject, @default_subject)
    lambda = Keyword.get(opts, :lambda, @default_lambda)

    maybe_subscribe(subject)
    maybe_subscribe(@epoch_close_subject)

    {:ok,
     %{
       subject: subject,
       lambda: lambda,
       retry_delay_ms: Keyword.get(opts, :retry_delay_ms, @default_retry_delay_ms),
       traces: %{},
       delayed_feedback: [],
       deferred_corrections: %{}
     }}
  end

  @impl true
  def handle_call(:runtime_state, _from, state) do
    {:reply,
     %{
       subject: state.subject,
       lambda: state.lambda,
       trace_count: map_size(state.traces),
       deferred_count: map_size(state.deferred_corrections)
     }, state}
  end

  @impl true
  def handle_cast({:register_trace, trace}, state) do
    case normalize_trace(trace) do
      {:ok, normalized} ->
        trace_key = trace_key(normalized.source_node, normalized.predicted_target)
        {:noreply, %{state | traces: Map.put(state.traces, trace_key, normalized)}}

      {:error, reason} ->
        Logger.debug("[STDPCoordinator] Ignoring invalid STDP trace: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: payload}}, state) do
    handle_info({:msg, topic, payload}, state)
  end

  def handle_info({:msg, topic, iodata}, state) when topic == @epoch_close_subject do
    Logger.info("[STDPCoordinator] Epoch Boundary Reached. Flushing causal matrix.")
    state = apply_epoch_causal_flush(state)
    {:noreply, state}
  end

  def handle_info({:msg, topic, iodata}, %{subject: subject} = state) when topic == subject do
    payload = IO.iodata_to_binary(iodata)

    case Karyon.NervousSystem.PredictionError.decode(payload) do
      {:ok, %Karyon.NervousSystem.PredictionError{} = prediction_error} ->
        # Buffer feedback instead of acting immediately
        new_feedback = [prediction_error | state.delayed_feedback]
        {:noreply, %{state | delayed_feedback: new_feedback}}

      {:error, reason} ->
        Logger.debug("[STDPCoordinator] Failed to decode operator nociception payload: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def handle_info({:retry_targeted_correction, correction_key}, state) do
    now = now_ms()
    state = prune_expired_traces(state, now)

    case Map.pop(state.deferred_corrections, correction_key) do
      {nil, deferred_state} ->
        {:noreply, %{state | deferred_corrections: deferred_state}}

      {%{attempt: attempt} = correction, deferred_state} when attempt >= @max_retry_attempts ->
        Logger.warning("[STDPCoordinator] Dropping targeted correction after bounded retries: #{inspect(correction_key)}")
        {:noreply, %{state | deferred_corrections: deferred_state}}

      {%{} = correction, deferred_state} ->
        state = %{state | deferred_corrections: deferred_state}
        route_targeted_correction(%{correction | attempt: correction.attempt + 1}, state)
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp apply_epoch_causal_flush(state) do
    Enum.each(state.delayed_feedback, fn feedback ->
      with :operator_induced <- normalize_source(feedback.source),
           {:ok, severity} <- validate_severity(feedback.severity),
           {:ok, targeted_update} <- normalize_targeted_update(feedback, severity) do
        
        feedback_clock = feedback.lamport_clock || 0
        
        Enum.each(state.traces, fn {_key, trace} ->
          delta_c = feedback_clock - trace.lamport_clock
          if delta_c >= 0 do
            # F * e^(-lambda * delta_c)
            delta_w = severity * :math.exp(-state.lambda * delta_c)
            
            payload = %{
              source_node: trace.source_node,
              predicted_target: trace.predicted_target,
              corrected_target: targeted_update.corrected_target,
              severity: delta_w,
              negative_spike: %{
                direction: :negative,
                source_node: trace.source_node,
                target_node: trace.predicted_target,
                severity: delta_w
              },
              positive_spike: %{
                direction: :positive,
                source_node: trace.source_node,
                target_node: targeted_update.corrected_target,
                severity: delta_w
              }
            }
            send(trace.stem_cell_pid, {:stdp_targeted_edge_update, payload})
          end
        end)
      end
    end)
    
    %{state | delayed_feedback: [], traces: %{}}
  end

  defp route_targeted_correction(correction, state) do
    correction_key = trace_key(correction.source_node, correction.predicted_target)

    with {:ok, trace} <- fetch_matching_trace(state, correction_key),
         :ok <- ensure_nodes_mutable(correction),
         :ok <- deliver_targeted_update(trace, correction) do
      {:noreply, state}
    else
      {:error, :trace_not_found} ->
        Logger.debug("[STDPCoordinator] No active targeted trace found for #{inspect(correction_key)}")
        {:noreply, state}

      {:error, :nodes_locked} ->
        schedule_retry(correction_key, correction, state)

      {:error, reason} ->
        Logger.debug("[STDPCoordinator] Dropping targeted STDP correction: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp fetch_matching_trace(state, correction_key) do
    case Map.get(state.traces, correction_key) do
      nil -> {:error, :trace_not_found}
      trace -> {:ok, trace}
    end
  end

  defp ensure_nodes_mutable(correction) do
    node_ids =
      [correction.source_node, correction.predicted_target, correction.corrected_target]
      |> Enum.uniq()

    case node_lock_status(node_ids) do
      {:ok, statuses} ->
        if Enum.any?(statuses, fn {_node_id, status} -> status != :unlocked end) do
          {:error, :nodes_locked}
        else
          :ok
        end

      {:error, _reason} ->
        :ok
    end
  end

  defp node_lock_status(node_ids) do
    cond do
      not Code.ensure_loaded?(Core.MetabolicDaemon) ->
        {:error, :metabolic_daemon_unavailable}

      pid = GenServer.whereis(Core.MetabolicDaemon) ->
        {:ok, GenServer.call(pid, {:get_node_lock_status, node_ids})}

      true ->
        {:error, :metabolic_daemon_unavailable}
    end
  end

  defp deliver_targeted_update(trace, correction) do
    payload = %{
      source_node: correction.source_node,
      predicted_target: correction.predicted_target,
      corrected_target: correction.corrected_target,
      severity: correction.severity,
      negative_spike: %{
        direction: :negative,
        source_node: correction.source_node,
        target_node: correction.predicted_target,
        severity: correction.severity
      },
      positive_spike: %{
        direction: :positive,
        source_node: correction.source_node,
        target_node: correction.corrected_target,
        severity: correction.severity
      }
    }

    send(trace.stem_cell_pid, {:stdp_targeted_edge_update, payload})
    :ok
  end

  defp schedule_retry(correction_key, correction, state) do
    deferred =
      state.deferred_corrections
      |> Map.put(correction_key, correction)

    Process.send_after(self(), {:retry_targeted_correction, correction_key}, state.retry_delay_ms)
    {:noreply, %{state | deferred_corrections: deferred}}
  end

  defp maybe_subscribe(subject) do
    case GenServer.whereis(:endocrine_gnat) do
      nil -> :ok
      pid -> NervousSystem.Endocrine.subscribe(pid, subject)
    end
  end

  defp normalize_trace(trace) do
    motor_action_id = Map.get(trace, :motor_action_id) || Map.get(trace, "motor_action_id")
    sensory_id = Map.get(trace, :sensory_id) || Map.get(trace, "sensory_id")
    source_node = Map.get(trace, :source_node) || Map.get(trace, "source_node") || sensory_id
    predicted_target = Map.get(trace, :predicted_target) || Map.get(trace, "predicted_target") || motor_action_id
    stem_cell_pid = Map.get(trace, :stem_cell_pid) || Map.get(trace, "stem_cell_pid")
    trace_timestamp = Map.get(trace, :lamport_clock) || Map.get(trace, "lamport_clock") || 0

    cond do
      not is_binary(source_node) -> {:error, :invalid_source_node}
      not is_binary(predicted_target) -> {:error, :invalid_predicted_target}
      not is_pid(stem_cell_pid) -> {:error, :invalid_stem_cell_pid}
      not Process.alive?(stem_cell_pid) -> {:error, :dead_stem_cell_pid}
      not is_integer(trace_timestamp) -> {:error, :invalid_lamport_clock}
      true ->
        {:ok,
         %{
           motor_action_id: to_string(predicted_target),
           sensory_id: to_string(source_node),
           source_node: to_string(source_node),
           predicted_target: to_string(predicted_target),
           stem_cell_pid: stem_cell_pid,
           lamport_clock: trace_timestamp
         }}
    end
  end

 

  defp validate_severity(value) when is_float(value) and value >= 0.0 and value <= 1.0, do: {:ok, value}
  defp validate_severity(value) when is_integer(value), do: validate_severity(value * 1.0)
  defp validate_severity(_value), do: {:error, :invalid_severity}

  defp normalize_targeted_update(prediction_error, severity) do
    source_node = normalize_binary(prediction_error.source_node)
    predicted_target = normalize_binary(prediction_error.predicted_target)
    corrected_target = normalize_binary(prediction_error.corrected_target)

    cond do
      source_node in [nil, ""] -> {:error, :missing_source_node}
      predicted_target in [nil, ""] -> {:error, :missing_predicted_target}
      corrected_target in [nil, ""] -> {:error, :missing_corrected_target}
      true ->
        {:ok,
         %{
           source_node: source_node,
           predicted_target: predicted_target,
           corrected_target: corrected_target,
           severity: severity
         }}
    end
  end

  defp normalize_source(source) when is_atom(source), do: source
  defp normalize_source("operator_induced"), do: :operator_induced
  defp normalize_source("OPERATOR_INDUCED"), do: :operator_induced
  defp normalize_source(_source), do: :unknown

  defp trace_key(source_node, predicted_target), do: "#{source_node}->#{predicted_target}"
  defp normalize_binary(value) when is_binary(value), do: value
  defp normalize_binary(_value), do: nil
end
