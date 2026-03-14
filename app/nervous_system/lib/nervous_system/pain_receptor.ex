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
    {:ok, synapse_pid} = NervousSystem.Synapse.start_link(type: :pub, bind: "tcp://127.0.0.1:5555")

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

    # Convert metadata to a structured JSON payload
    payload = %{
      type: "nociception",
      timestamp: DateTime.utc_now(),
      metadata: sanitize_metadata(metadata)
    }

    case Jason.encode(payload) do
      {:ok, json} ->
        NervousSystem.Synapse.send_signal(synapse_pid, json)
      {:error, reason} ->
        Logger.error("[PainReceptor] Failed to serialize pain signal: #{inspect(reason)}")
    end
  end

  defp sanitize_metadata(metadata) do
    # Metadata often contains PIDs and other non-serializable terms.
    # For MVP, we'll convert everything to strings.
    Map.new(metadata, fn {k, v} -> {k, inspect(v)} end)
  end
end
