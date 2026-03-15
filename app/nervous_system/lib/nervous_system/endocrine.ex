defmodule NervousSystem.Endocrine do
  @moduledoc """
  Global ambient telemetry broadcaster via NATS Core (Gnat).
  Represents endocrine gradients tracking holistic cluster starvation.
  """

  @doc """
  Connects to the global NATS network.
  """
  def start_connection(_client_id, url \\ "nats://localhost:4222") do
    # In NATS, we don't necessarily need a client_id in the same way as MQTT for basic pub/sub.
    # We'll use Gnat.start_link/1 for now.
    [_protocol, host_port] = String.split(url, "://")
    [host, port] = String.split(host_port, ":")
    Gnat.start_link(%{host: host, port: String.to_integer(port)})
  end

  @doc """
  Broadcasts an ambient metabolic pressure signal to the cluster.
  """
  def publish_gradient(gnat, topic, payload) do
    Gnat.pub(gnat, topic, payload)
  end

  @doc """
  Subscribes the current process to an endocrine gradient topic.
  """
  def subscribe(gnat, topic) do
    case Gnat.sub(gnat, self(), topic) do
      {:ok, _id} -> :ok
      err -> err
    end
  end

  @doc """
  Returns the globally registered endocrine NATS PID if available.
  """
  def get_gnat() do
    Process.whereis(:endocrine_gnat)
  end
end
