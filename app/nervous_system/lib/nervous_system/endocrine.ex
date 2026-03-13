defmodule NervousSystem.Endocrine do
  @moduledoc """
  Global ambient telemetry broadcaster via NATS Core (Tortoise).
  Represents endocrine gradients tracking holistic cluster starvation.
  """

  @doc """
  Connects to the global NATS network.
  """
  def start_connection(client_id, url \\ "nats://localhost:4222") do
    # Note: Tortoise is an MQTT client. Using it for NATS as per specs.
    # We use a standard MQTT TCP transport for now.
    Tortoise.Connection.start_link(
      client_id: client_id,
      server: {Tortoise.Transport.Tcp, host: "localhost", port: 1883},
      handler: {Tortoise.Handler.Logger, []}
    )
  end

  @doc """
  Broadcasts an ambient metabolic pressure signal to the cluster.
  """
  def publish_gradient(client_id, topic, payload) do
    Tortoise.publish(client_id, topic, payload)
  end
end
