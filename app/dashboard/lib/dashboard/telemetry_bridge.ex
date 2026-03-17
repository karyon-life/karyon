defmodule Dashboard.TelemetryBridge do
  use GenServer
  require Logger
  alias Core.Native

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    :telemetry.attach(
      "metabolic-bridge",
      [:karyon, :metabolism, :poll],
      &__MODULE__.handle_event/4,
      nil
    )
    {:ok, %{}}
  end

  def handle_event([:karyon, :metabolism, :poll], measurements, metadata, _config) do
    l3_misses =
      case Native.read_l3_misses() do
        {:ok, value} -> value
        _ -> nil
      end

    iops =
      case Native.read_iops() do
        {:ok, value} -> value
        _ -> nil
      end

    # Broadcast to Phoenix PubSub
    Phoenix.PubSub.broadcast(
      Dashboard.PubSub,
      "metabolic_flux",
      {:metabolic_update, %{
        l3_misses: l3_misses,
        run_queue: :erlang.statistics(:run_queue),
        iops: iops,
        pressure: metadata.pressure,
        atp: 1.0 - (measurements.pressure * 0.3)
      }}
    )
  end
end
