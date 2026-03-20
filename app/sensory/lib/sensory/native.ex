defmodule Sensory.Native do
  @moduledoc """
  NIF bridge for the Sensory layer transport primitives.
  """
  alias Sensory.Raw

  def zmq_publish_tensor(topic, payload), do: Raw.zmq_publish_tensor(topic, payload)
  def zmq_subscribe_sensory(topic), do: Raw.zmq_subscribe_sensory(topic)
end
