defmodule NervousSystem.PainReceptor do
  @moduledoc """
  The Pain Receptor intercepts application crash logs via Telemetry or Erlang's :logger.
  It converts biological failure states (like process crashes) into high-priority prediction errors
  and routes them recursively back to the Synapse.
  """
  use GenServer
  require Logger

  @prediction_error_schema_version "2026-03-18"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Handle both Map (from tests) and Keyword (from standard supervisor)
    nociception_address = case opts do
      m when is_map(m) -> Map.get(m, :address)
      l when is_list(l) -> Keyword.get(l, :address)
    end
    
    nociception_address = nociception_address || Application.get_env(:nervous_system, :nociception_port, 5555)
    
    bind_uri = case nociception_address do
      addr when is_binary(addr) -> addr
      port when is_integer(port) -> "tcp://127.0.0.1:#{port}"
    end

    {:ok, synapse_pid} =
      NervousSystem.Synapse.start_link(type: :pub, bind: bind_uri, name: :pain_synapse, hwm: 500)

    handler_id = "pain-receptor-handler-#{inspect(self())}"

    # Attach to standard OTP crash events using Telemetry.
    :telemetry.attach(
      handler_id,
      [:logger, :error],
      &__MODULE__.handle_pain_signal/4,
      %{receptor: self()}
    )

    {:ok,
     %{
       synapse: synapse_pid,
       original_opts: opts,
       telemetry_handler_id: handler_id,
       last_pain_time: 0,
       last_fingerprint: nil,
       last_emitted_pain: nil
     }}
  end

  def handle_pain_signal(_event, _measurements, metadata, %{receptor: receptor_pid}) do
    if Process.alive?(receptor_pid) do
      GenServer.cast(receptor_pid, {:telemetry_pain, metadata})
    end
  end

  @impl true
  def handle_info({:telemetry_event, _, _, %{error: error, stacktrace: _stack}, %{module: mod}}, state) do
    # Filter out noisy modules or internal test errors that shouldn't trigger systemic pain
    if mod not in [NervousSystem.PainReceptorTest, Core.ChaosTest] do
      now = System.monotonic_time(:millisecond)
      last_pain = Map.get(state, :last_pain_time, 0)
      
      # Limit to 10 pain signals per second to prevent metabolic collapse
      if now - last_pain > 100 do
        send_pain(state, error)
        {:noreply, Map.put(state, :last_pain_time, now)}
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @doc """
  Manually triggers a nociception signal (e.g., from Sandbox Console).
  """
  def trigger_nociception(metadata) do
    GenServer.cast(__MODULE__, {:trigger_nociception, metadata})
  end

  def learning_phase, do: "prediction_error"

  @impl true
  def handle_cast({:trigger_nociception, metadata}, state) do
    {:noreply, emit_pain(metadata, "manual", state)}
  end

  @impl true
  def handle_cast({:telemetry_pain, metadata}, state) do
    {:noreply, emit_pain(metadata, "telemetry", state)}
  end

  @impl true
  def terminate(_reason, state) do
    :telemetry.detach(state.telemetry_handler_id)
    :ok
  end

  defp sanitize_metadata(metadata) do
    # Proto maps require string keys and string values.
    Map.new(metadata, fn {k, v} -> {serialize_term(k), serialize_term(v)} end)
  end

  defp emit_pain(metadata, source, state) do
    normalized_metadata = normalize_metadata(metadata)
    msg_mod = Map.get(normalized_metadata, "module")
    fingerprint = pain_fingerprint(normalized_metadata)
    now = System.monotonic_time(:millisecond)

    cond do
      recursive_module?(msg_mod) ->
        state

      duplicate_fingerprint?(state, fingerprint, now) ->
        state

      true ->
        Logger.info("[PainReceptor] Structural error intercepted! Preparing active inference nociception signal.")

        proto_timestamp = System.system_time(:second)
        recorded_at = iso_timestamp()

        enriched_metadata =
          normalized_metadata
          |> Map.put_new("event_source", source)
          |> Map.put_new("severity", "high")
          |> Map.put_new("schema_version", @prediction_error_schema_version)
          |> Map.put_new("learning_phase", learning_phase())
          |> Map.put_new("learning_edge", "prediction_error->plasticity")
          |> Map.put_new("recorded_at", recorded_at)
          |> Map.put_new("timestamp_unit", "iso8601")
          |> Map.put_new("proto_timestamp", Integer.to_string(proto_timestamp))
          |> Map.put_new("proto_timestamp_unit", "second")
          |> Map.put_new("correction_type", "pending_graph_correction")
          |> Map.put_new("correction_status", "pending")
          |> Map.put("event_fingerprint", fingerprint)
          |> Map.put_new("trace_id", "pain:#{fingerprint}:#{System.system_time(:millisecond)}")

        msg = %Karyon.NervousSystem.PredictionError{
          type: "nociception",
          message: "Structural error intercepted in #{msg_mod || "unknown_module"}",
          timestamp: proto_timestamp,
          metadata: sanitize_metadata(enriched_metadata),
          cell_id: "pain-receptor"
        }

        send_encoded_pain(msg, state)

        %{state | last_pain_time: now, last_fingerprint: fingerprint, last_emitted_pain: enriched_metadata}
    end
  end

  defp send_pain(state, error) do
    emit_pain(%{error: inspect(error), severity: "high"}, "internal", state)
  end

  defp send_encoded_pain(msg, state) do
    if Process.alive?(state.synapse) do
      case Karyon.NervousSystem.PredictionError.encode(msg) do
        {:ok, binary} ->
          NervousSystem.Synapse.send_signal(state.synapse, binary)

        {:error, reason} ->
          Logger.info("[PainReceptor] Failed to encode pain signal: #{inspect(reason)}")
      end
    else
      Logger.warning("[PainReceptor] Attempted to send pain signal but Synapse process is dead.")
    end
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    Map.new(metadata, fn {key, value} -> {serialize_term(key), serialize_term(value)} end)
  end

  defp normalize_metadata(_), do: %{}

  defp recursive_module?(nil), do: false
  defp recursive_module?(msg_mod), do: msg_mod in ["Elixir.NervousSystem.Synapse", "chumak", "Elixir.NervousSystem.PainReceptor"]

  defp duplicate_fingerprint?(state, fingerprint, now) do
    state.last_fingerprint == fingerprint and now - Map.get(state, :last_pain_time, 0) <= 100
  end

  defp pain_fingerprint(metadata) do
    module = Map.get(metadata, "module", "unknown")
    reason = Map.get(metadata, "reason") || Map.get(metadata, "error") || "unknown"
    "#{module}:#{reason}"
  end

  defp iso_timestamp do
    DateTime.utc_now() |> DateTime.truncate(:microsecond) |> DateTime.to_iso8601()
  end

  defp serialize_term(term) when is_atom(term), do: Atom.to_string(term)
  defp serialize_term(term) when is_binary(term), do: term
  defp serialize_term(term), do: inspect(term)
end
