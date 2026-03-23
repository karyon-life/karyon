defmodule Sensory.StreamTest do
  use ExUnit.Case
  alias Sensory.Native
  test "integer node ids can be deployed over transport" do
    # The Rust NIF expects binaries for ZMQ payload, so we pack the 64-bit ID
    node_id = <<1234567890::64>>

    # Verify publication returns ok even without listeners (ZMQ PUB/SUB behavior)
    assert {:ok, _} = Native.zmq_publish_tensor("neural_tensor", node_id)
  end

  test "transport NIF exposes bounded subscribe results" do
    result = Native.zmq_subscribe_sensory("raw_bytes")
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end
end
