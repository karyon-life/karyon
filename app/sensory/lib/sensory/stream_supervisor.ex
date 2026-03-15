defmodule Sensory.StreamSupervisor do
  @moduledoc """
  Supervises ZeroMQ sensory ingestion processes.
  """
  use GenServer
  alias Sensory.Native

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start the ingestion loop in a separate task or process
    # for demo we'll just trigger a periodic fetch or simulate it
    send(self(), :listen)
    {:ok, %{topics: ["neural_tensor", "telemetry"]}}
  end

  @impl true
  def handle_info(:listen, state) do
    # Example: Listen for neural tensors from peripheral cells
    Enum.each(state.topics, fn topic ->
      # This is a non-blocking check in the NIF with 1s timeout
      # In a real system, this would be a high-performance loop in Rust or a dedicated Actor
      case Native.zmq_subscribe_sensory(topic) do
        {:ok, payload} ->
          # Process sensory payload (e.g., dequantize and insert into graph)
          handle_payload(topic, payload)
        {:error, _reason} ->
          :ok
      end
    end)

    # Schedule next check
    Process.send_after(self(), :listen, 100)
    {:noreply, state}
  end

  defp handle_payload("neural_tensor", payload) do
    _tensor = Sensory.Quantizer.dequantize(payload)
    # Log or push to Rhizome
    # IO.inspect(tensor, label: "Received Neural Tensor")
    :ok
  end

  defp handle_payload(_topic, _payload), do: :ok
end
