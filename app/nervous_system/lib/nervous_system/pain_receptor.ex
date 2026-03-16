defmodule NervousSystem.PainReceptor do
  @moduledoc """
  The Pain Receptor intercepts application crash logs via Telemetry or Erlang's :logger.
  It converts biological failure states (like process crashes) into high-priority prediction errors
  and routes them recursively back to the Synapse.
  """
  use GenServer
  require Logger

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

    {:ok, synapse_pid} = NervousSystem.Synapse.start_link(type: :pub, bind: bind_uri, name: :pain_synapse, hwm: 500)

    # Attach to standard OTP crash events using Telemetry.
    :telemetry.attach(
      "pain-receptor-handler",
      [:logger, :error],
      &__MODULE__.handle_pain_signal/4,
      %{synapse: synapse_pid}
    )

    {:ok, %{synapse: synapse_pid, original_opts: opts}}
  end

  def handle_pain_signal(_event, _measurements, metadata, %{synapse: synapse_pid}) do
    # A crash has occurred. We must signal nociception.
    # Use info level to avoid recursion if PainReceptor is listening to error level
    Logger.info("[PainReceptor] Structural error intercepted! Preparing active inference nociception signal.")

    # Filter out nervous system internal errors to avoid recursion loops
    msg_mod = Map.get(metadata, :module)
    if msg_mod not in [NervousSystem.Synapse, :chumak, NervousSystem.PainReceptor] do
      # Create a structured Protobuf message
      msg = %Karyon.NervousSystem.PredictionError{
        type: "nociception",
        message: "Key error intercepted in #{inspect(msg_mod)}",
        timestamp: System.system_time(:second),
        metadata: sanitize_metadata(metadata),
        cell_id: "pain-receptor"
      }

      if Process.alive?(synapse_pid) do
        case Karyon.NervousSystem.PredictionError.encode(msg) do
          {:ok, binary} ->
            NervousSystem.Synapse.send_signal(synapse_pid, binary)
          {:error, reason} ->
            # Don't use Logger.error here to avoid recursion
            Logger.info("[PainReceptor] Failed to encode pain signal: #{inspect(reason)}")
        end
      end
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

  defp send_pain(state, _error) do
    Logger.info("[PainReceptor] Structural error intercepted! Preparing active inference nociception signal.")
    
    # Use correct ProtoBuf fields from prediction_error.proto
    error_msg = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      message: "Homeostatic variance exceeded",
      timestamp: System.system_time(:millisecond),
      cell_id: "pain-receptor"
    }

    payload = Karyon.NervousSystem.PredictionError.encode!(error_msg)
    
    if Process.alive?(state.synapse) do
      NervousSystem.Synapse.send_signal(state.synapse, payload)
    else
      Logger.warning("[PainReceptor] Attempted to send pain signal but Synapse process is dead.")
    end
  end

  @doc """
  Manually triggers a nociception signal (e.g., from Sandbox Console).
  """
  def trigger_nociception(metadata) do
    GenServer.cast(__MODULE__, {:trigger_nociception, metadata})
  end

  @impl true
  def handle_cast({:trigger_nociception, metadata}, state) do
    handle_pain_signal(nil, nil, metadata, %{synapse: state.synapse})
    {:noreply, state}
  end

  defp sanitize_metadata(metadata) do
    # Proto maps require string keys and string values.
    Map.new(metadata, fn {k, v} -> {serialize_term(k), serialize_term(v)} end)
  end

  defp serialize_term(term) when is_atom(term), do: Atom.to_string(term)
  defp serialize_term(term) when is_binary(term), do: term
  defp serialize_term(term), do: inspect(term)
end
