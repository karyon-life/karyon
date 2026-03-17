defmodule Dashboard.TelemetryBridge do
  use GenServer

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
    Phoenix.PubSub.broadcast(
      Dashboard.PubSub,
      "metabolic_flux",
      {:metabolic_update, %{
        l3_misses: Map.get(metadata, :l3_misses),
        run_queue: Map.get(metadata, :run_queue, 0),
        iops: Map.get(metadata, :iops),
        pressure: metadata.pressure,
        atp: Map.get(metadata, :atp, 1.0 - measurements.pressure * 0.3),
        preflight_status: Map.get(metadata, :preflight_status, :ok)
      }}
    )
  end
end
