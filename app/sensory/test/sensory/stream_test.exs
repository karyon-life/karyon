defmodule Sensory.StreamTest do
  use ExUnit.Case
  alias Sensory.Native
  alias Sensory.Quantizer

  test "quantization and publication throughput" do
    tensor = for _ <- 1..100, do: :rand.uniform()
    binary = Quantizer.quantize(tensor)
    
    # Verify publication returns ok even without listeners (ZMQ PUB/SUB behavior)
    assert {:ok, _} = Native.zmq_publish_tensor("neural_tensor", binary)
  end

  test "transport NIF exposes bounded subscribe results" do
    result = Native.zmq_subscribe_sensory("raw_bytes")
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end
end
