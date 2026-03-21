defmodule Sensory.STDPCoordinator do
  @moduledoc """
  Correlates operator-induced nociception with recent motor traces using
  a monotonic eligibility window and emits typed STDP prediction errors.
  """

  use GenServer
  require Logger

  @default_window_ms 4_000
  @min_window_ms 3_000
  @max_window_ms 5_000
  @default_subject "operator.nociception"
  @default_retry_delay_ms 50
  @max_retry_attempts 3

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
    window_ms = normalize_window_ms(Keyword.get(opts, :window_ms, @default_window_ms))
    subject = Keyword.get(opts, :subject, @default_subject)

    maybe_subscribe(subject)

    {:ok,
     %{
       subject: subject,
       window_ms: window_ms,
       retry_delay_ms: Keyword.get(opts, :retry_delay_ms, @default_retry_delay_ms),
       traces: %{},
       deferred_corrections: %{}
     }}
  end

  @impl true
  def handle_call(:runtime_state, _from, state) do
    state = prune_expired_traces(state, now_ms())

    {:reply,
     %{
       subject: state.subject,
       window_ms: state.window_ms,
       trace_count: map_size(state.traces),
       deferred_count: map_size(state.deferred_corrections)
     }, state}
  end

  @impl true
  def handle_cast({:register_trace, trace}, state) do
    now = now_ms()
    state = prune_expired_traces(state, now)

    case normalize_trace(trace, now) do
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

  def handle_info({:msg, topic, iodata}, %{subject: subject} = state) when topic == subject do
    payload = IO.iodata_to_binary(iodata)
    now = now_ms()
    state = prune_expired_traces(state, now)

    case Karyon.NervousSystem.PredictionError.decode(payload) do
      {:ok, %Karyon.NervousSystem.PredictionError{} = prediction_error} ->
        route_operator_nociception(prediction_error, state)

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

  defp route_operator_nociception(prediction_error, state) do
    with :operator_induced <- normalize_source(prediction_error.source),
         {:ok, severity} <- validate_severity(prediction_error.severity),
         {:ok, targeted_update} <- normalize_targeted_update(prediction_error, severity) do
      route_targeted_correction(Map.put(targeted_update, :attempt, 0), state)
    else
      other ->
        Logger.debug("[STDPCoordinator] Dropping nociception event: #{inspect(other)}")
        {:noreply, state}
    end
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

  defp normalize_trace(trace, recorded_at) do
    motor_action_id = Map.get(trace, :motor_action_id) || Map.get(trace, "motor_action_id")
    sensory_id = Map.get(trace, :sensory_id) || Map.get(trace, "sensory_id")
    source_node = Map.get(trace, :source_node) || Map.get(trace, "source_node") || sensory_id
    predicted_target = Map.get(trace, :predicted_target) || Map.get(trace, "predicted_target") || motor_action_id
    stem_cell_pid = Map.get(trace, :stem_cell_pid) || Map.get(trace, "stem_cell_pid")
    trace_timestamp = Map.get(trace, :recorded_at_ms) || Map.get(trace, "recorded_at_ms") || recorded_at

    cond do
      not is_binary(source_node) -> {:error, :invalid_source_node}
      not is_binary(predicted_target) -> {:error, :invalid_predicted_target}
      not is_pid(stem_cell_pid) -> {:error, :invalid_stem_cell_pid}
      not Process.alive?(stem_cell_pid) -> {:error, :dead_stem_cell_pid}
      not is_integer(trace_timestamp) -> {:error, :invalid_recorded_at}
      true ->
        {:ok,
         %{
           motor_action_id: to_string(predicted_target),
           sensory_id: to_string(source_node),
           source_node: to_string(source_node),
           predicted_target: to_string(predicted_target),
           stem_cell_pid: stem_cell_pid,
           recorded_at_ms: trace_timestamp
         }}
    end
  end

  defp prune_expired_traces(state, now) do
    traces =
      Enum.reduce(state.traces, %{}, fn {motor_action_id, trace}, acc ->
        if Process.alive?(trace.stem_cell_pid) and now - trace.recorded_at_ms <= state.window_ms do
          Map.put(acc, motor_action_id, trace)
        else
          acc
        end
      end)

    %{state | traces: traces}
  end

  defp normalize_window_ms(value) when is_integer(value) do
    cond do
      value < @min_window_ms -> @min_window_ms
      value > @max_window_ms -> @max_window_ms
      true -> value
    end
  end

  defp normalize_window_ms(_value), do: @default_window_ms

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

  defp now_ms, do: System.monotonic_time(:millisecond)
end
