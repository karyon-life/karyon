defmodule NervousSystem.Synapse do
  @moduledoc """
  Manages peer-to-peer data streaming using ZeroMQ (via :chumak).
  Enforces zero-buffer active inference determinism by severely capping message sizes and queues (HWM).
  """

  @doc """
  Initializes a Synaptic connection (PUB/SUB or PUSH/PULL)
  We strictly cap the buffer to enforce physical pain/prediction errors during saturation.
  """
  def start_link(opts \\ []) do
    # Implementation of a deterministic PUSH/PULL or SUB socket.
    # We must restrict the High-Water Mark (hwm) to 1 to simulate biological synapse saturation.
    
    # Use dynamically assigned ports for testability/MVP unless fixed in opts
    {type, bind_addr} = case opts do
      [type: t, bind: b] -> {t, b}
      _ -> {:push, 'tcp://127.0.0.1:0'}
    end

    {:ok, pid} = :chumak.socket(type)
    :chumak.set_socket_option(pid, :sndhwm, 1) # Zero-buffering constraint!
    :chumak.set_socket_option(pid, :rcvhwm, 1)

    # Parse bind_addr like 'tcp://127.0.0.1:1234'
    # For MVP, we'll just hardcode tcp and 127.0.0.1, 0 if it's default
    case :chumak.bind(pid, :tcp, ~c"127.0.0.1", 0) do
      {:ok, port} -> {:ok, {pid, port}}
      {:error, reason} -> {:error, reason}
      _ -> {:ok, pid}
    end
  end
end
