defmodule NervousSystem.PainReceptor do
  @moduledoc """
  The Pain Receptor intercepts application crash logs via Telemetry or Erlang's :logger.
  It converts biological failure states (like process crashes) into high-priority prediction errors
  and routes them recursively back to the Synapse.
  """
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    # Initialize a PUB synapse for broadcasting pain/nociception signals
    nociception_port = Application.get_env(:nervous_system, :nociception_port, 5555)
    {:ok, synapse_pid} = NervousSystem.Synapse.start_link(type: :pub, bind: "tcp://127.0.0.1:#{nociception_port}")

    # Attach to standard OTP crash events using Telemetry.
    :telemetry.attach(
      "pain-receptor-handler",
      [:logger, :error],
      &__MODULE__.handle_pain_signal/4,
      %{synapse: synapse_pid}
    )

    {:ok, Map.put(state, :synapse, synapse_pid)}
  end

  @doc """
  Converts captured errors into structured prediction "pain" and pipes to ZeroMQ.
  """
  def handle_pain_signal(_event, _measurements, metadata, %{synapse: synapse_pid}) do
    # A crash has occurred. We must signal nociception.
    Logger.error("[PainReceptor] Structural error intercepted! Preparing active inference nociception signal.")

    # Create a structured Protobuf-compatible message
    msg = NervousSystem.Protos.PredictionError.new(
      type: "nociception",
      message: "Structural error intercepted",
      timestamp: System.system_time(:second),
      metadata: sanitize_metadata(metadata),
      cell_id: "pain-receptor"
    )

    case NervousSystem.Protos.PredictionError.encode(msg) do
      json ->
        NervousSystem.Synapse.send_signal(synapse_pid, json)
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
    # Metadata often contains PIDs and other non-serializable terms.
    # For MVP, we'll convert everything to strings.
    Map.new(metadata, fn {k, v} -> {k, inspect(v)} end)
  end
end
