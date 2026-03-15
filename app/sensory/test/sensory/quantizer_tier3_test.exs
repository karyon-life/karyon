defmodule Sensory.QuantizerTier3Test do
  use ExUnit.Case
  alias Sensory.Quantizer
  use ExUnitProperties

  property "Quantization: Round-trip fidelity (8-bit)" do
    check all tensor <- list_of(float(min: 0.0, max: 1.0), length: 1..100) do
      binary = Quantizer.quantize(tensor)
      recovered = Quantizer.dequantize(binary)
      
      # Precision loss is expected with 8-bit quantization
      # Max error should be 1/255
      Enum.zip(tensor, recovered)
      |> Enum.each(fn {orig, dest} ->
        assert_in_delta orig, dest, 0.005 # 1/255 approx 0.0039
      end)
    end
  end
end
