defmodule Sensory.Quantizer do
  @moduledoc """
  Handles quantization and normalization of sensory data for high-bandwidth streaming.
  """

  @doc """
  Quantizes a list of floats (neural tensor) into a bit-packed binary for ZMQ streaming.
  """
  def quantize(tensor) when is_list(tensor) do
    # Simple 8-bit quantization for demo purposes
    tensor
    |> Enum.map(fn val ->
      rounded = round(val * 255)
      min(max(rounded, 0), 255)
    end)
    |> :binary.list_to_bin()
  end

  @doc """
  Dequantizes a binary core back into a float-based tensor.
  """
  def dequantize(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(fn byte -> byte / 255.0 end)
  end
end
