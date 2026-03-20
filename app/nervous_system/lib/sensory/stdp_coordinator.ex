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
       traces: %{}
     }}
  end

  @impl true
  def handle_call(:runtime_state, _from, state) do
    state = prune_expired_traces(state, now_ms())

    {:reply, %{subject: state.subject, window_ms: state.window_ms, trace_count: map_size(state.traces)}, state}
  end

  @impl true
  def handle_cast({:register_trace, trace}, state) do
    now = now_ms()
    state = prune_expired_traces(state, now)

    case normalize_trace(trace, now) do
      {:ok, normalized} ->
        {:noreply, %{state | traces: Map.put(state.traces, normalized.motor_action_id, normalized)}}

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

  def handle_info(_message, state), do: {:noreply, state}

  defp route_operator_nociception(prediction_error, state) do
    with :operator_induced <- normalize_source(prediction_error.source),
         {:ok, severity} <- validate_severity(prediction_error.severity) do
      Enum.each(state.traces, fn {_motor_action_id, trace} ->
        send(trace.stem_cell_pid, {:stdp_prediction_error, trace.sensory_id, severity})
      end)

      {:noreply, state}
    else
      other ->
        Logger.debug("[STDPCoordinator] Dropping nociception event: #{inspect(other)}")
        {:noreply, state}
    end
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
    stem_cell_pid = Map.get(trace, :stem_cell_pid) || Map.get(trace, "stem_cell_pid")
    trace_timestamp = Map.get(trace, :recorded_at_ms) || Map.get(trace, "recorded_at_ms") || recorded_at

    cond do
      not is_binary(motor_action_id) -> {:error, :invalid_motor_action_id}
      not is_binary(sensory_id) -> {:error, :invalid_sensory_id}
      not is_pid(stem_cell_pid) -> {:error, :invalid_stem_cell_pid}
      not Process.alive?(stem_cell_pid) -> {:error, :dead_stem_cell_pid}
      not is_integer(trace_timestamp) -> {:error, :invalid_recorded_at}
      true -> {:ok, %{motor_action_id: motor_action_id, sensory_id: sensory_id, stem_cell_pid: stem_cell_pid, recorded_at_ms: trace_timestamp}}
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

  defp normalize_source(source) when is_atom(source), do: source
  defp normalize_source("operator_induced"), do: :operator_induced
  defp normalize_source("OPERATOR_INDUCED"), do: :operator_induced
  defp normalize_source(_source), do: :unknown

  defp now_ms, do: System.monotonic_time(:millisecond)
end
