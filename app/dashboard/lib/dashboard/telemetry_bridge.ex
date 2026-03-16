defmodule Dashboard.TelemetryBridge do
  use GenServer
  require Logger

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
    # Broadcast to Phoenix PubSub
    Phoenix.PubSub.broadcast(
      Dashboard.PubSub,
      "metabolic_flux",
      {:metabolic_update, %{
        l3_misses: :rand.uniform(20000), # Mocking for now, or fetch from state
        run_queue: :erlang.statistics(:run_queue),
        iops: :rand.uniform(1500),
        pressure: metadata.pressure,
        atp: 1.0 - (measurements.pressure * 0.3)
      }}
    )
  end
end
