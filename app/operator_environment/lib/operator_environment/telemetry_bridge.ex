defmodule OperatorEnvironment.TelemetryBridge do
  use GenServer

  @telemetry_id "operator-environment-telemetry-bridge"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    case :telemetry.attach(@telemetry_id, [:karyon, :metabolism, :poll], &__MODULE__.handle_event/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end

    {:ok, %{}}
  end

  def handle_event([:karyon, :metabolism, :poll], measurements, metadata, _config) do
    payload = %{
      free_energy: Map.get(measurements, :pressure, 0.0) |> normalize_float(),
      pressure: Map.get(metadata, :pressure, :low),
      atp: Map.get(metadata, :atp, 1.0),
      l3_misses: Map.get(metadata, :l3_misses),
      run_queue: Map.get(metadata, :run_queue, 0),
      iops: Map.get(metadata, :iops),
      consciousness_state: Map.get(metadata, :consciousness_state, :awake),
      membrane_open: Map.get(metadata, :membrane_open, true),
      motor_output_open: Map.get(metadata, :motor_output_open, true),
      observed_at: System.system_time(:millisecond)
    }

    NervousSystem.PubSub.broadcast(:telemetry, payload)
  end

  defp normalize_float(value) when is_float(value), do: Float.round(value, 3)
  defp normalize_float(value) when is_integer(value), do: value * 1.0
  defp normalize_float(_value), do: 0.0
end
