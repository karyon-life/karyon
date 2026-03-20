defmodule Sensory.Raw do
  @moduledoc false

  use Rustler,
    otp_app: :sensory,
    crate: "sensory_nif"

  def zmq_publish_tensor(_topic, _payload), do: :erlang.nif_error(:nif_not_loaded)
  def zmq_subscribe_sensory(_topic), do: :erlang.nif_error(:nif_not_loaded)
end
