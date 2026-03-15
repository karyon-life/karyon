defmodule Sensory.QuantizerTest do
  use ExUnit.Case
  alias Sensory.Quantizer

  test "quantize/1 converts floats to bit-packed binary (8-bit)" do
    tensor = [0.0, 0.5, 1.0, 0.25]
    binary = Quantizer.quantize(tensor)
    
    assert byte_size(binary) == 4
    assert binary == <<0, 128, 255, 64>>
  end

  test "dequantize/1 reconstructs floats from binary" do
    binary = <<0, 128, 255, 64>>
    tensor = Quantizer.dequantize(binary)
    
    assert length(tensor) == 4
    [v1, v2, v3, v4] = tensor
    
    assert_in_delta v1, 0.0, 0.01
    assert_in_delta v2, 0.5, 0.01
    assert_in_delta v3, 1.0, 0.01
    assert_in_delta v4, 0.25, 0.01
  end

  test "quantization handles values out of range [0, 1]" do
    tensor = [-1.0, 2.0]
    binary = Quantizer.quantize(tensor)
    assert binary == <<0, 255>>
  end
end
