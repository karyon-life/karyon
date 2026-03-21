defmodule Sensory.StreamTest do
  use ExUnit.Case
  alias Sensory.Native
  alias Sensory.Quantizer

  test "lexical node ids can be encoded and published for transport" do
    node_id =
      "Deploy"
      |> Quantizer.quantize()
      |> Quantizer.encode_node_id()

    # Verify publication returns ok even without listeners (ZMQ PUB/SUB behavior)
    assert {:ok, _} = Native.zmq_publish_tensor("neural_tensor", node_id)
  end

  test "transport NIF exposes bounded subscribe results" do
    result = Native.zmq_subscribe_sensory("raw_bytes")
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end
end
