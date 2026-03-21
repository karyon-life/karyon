defmodule Sensory.Quantizer do
  @moduledoc """
  Deterministic lexical hashing for the sensory language boundary.

  This module accepts discrete string tokens and returns exact, immutable 64-bit
  integer identifiers suitable for stable Memgraph node addressing.
  """

  import Bitwise

  @mask_64 0xFFFFFFFFFFFFFFFF
  @c1 0x87C37B91114253D5
  @c2 0x4CF5AD432745937F
  @fmix_1 0xFF51AFD7ED558CCD
  @fmix_2 0xC4CEB9FE1A85EC53
  @seed 0

  @doc """
  Hashes a discrete lexical token into a deterministic 64-bit integer.

  The token is preserved exactly as provided; no case folding, trimming, or
  stemming is performed.
  """
  @spec quantize(String.t()) :: non_neg_integer()
  def quantize(token) when is_binary(token) and byte_size(token) > 0 do
    token
    |> murmur3_x64_128(@seed)
    |> elem(0)
  end

  def quantize(token) when is_binary(token) do
    raise ArgumentError, "quantize/1 expects a non-empty binary token"
  end

  def quantize(_token) do
    raise ArgumentError, "quantize/1 expects a binary token"
  end

  @doc """
  Alias for `quantize/1` when a lexical Memgraph node id is desired explicitly.
  """
  @spec node_id(String.t()) :: non_neg_integer()
  def node_id(token), do: quantize(token)

  @doc """
  Encodes a 64-bit node id into a fixed-width transport binary.
  """
  @spec encode_node_id(non_neg_integer()) :: <<_::64>>
  def encode_node_id(node_id) when is_integer(node_id) and node_id >= 0 and node_id <= @mask_64 do
    <<node_id::unsigned-big-64>>
  end

  def encode_node_id(_node_id) do
    raise ArgumentError, "encode_node_id/1 expects a 64-bit unsigned integer"
  end

  @doc """
  Decodes a fixed-width transport binary back into the exact 64-bit node id.
  """
  @spec decode_node_id(binary()) :: non_neg_integer()
  def decode_node_id(<<node_id::unsigned-big-64>>), do: node_id

  def decode_node_id(_payload) do
    raise ArgumentError, "decode_node_id/1 expects an 8-byte binary payload"
  end

  defp murmur3_x64_128(data, seed) when is_binary(data) and is_integer(seed) do
    {body, tail} = split_body_and_tail(data)

    {h1, h2} =
      Enum.reduce(body, {seed &&& @mask_64, seed &&& @mask_64}, fn <<k1::little-unsigned-64, k2::little-unsigned-64>>, {h1, h2} ->
        k1 =
          k1
          |> mul64(@c1)
          |> rotl64(31)
          |> mul64(@c2)

        h1 =
          h1
          |> bxor(k1)
          |> rotl64(27)
          |> add64(h2)
          |> mul64(5)
          |> add64(0x52DCE729)

        k2 =
          k2
          |> mul64(@c2)
          |> rotl64(33)
          |> mul64(@c1)

        h2 =
          h2
          |> bxor(k2)
          |> rotl64(31)
          |> add64(h1)
          |> mul64(5)
          |> add64(0x38495AB5)

        {h1, h2}
      end)

    {h1, h2} = mix_tail(tail, h1, h2)
    finalize_hash(h1, h2, byte_size(data))
  end

  defp split_body_and_tail(data) do
    body_size = div(byte_size(data), 16) * 16
    <<body::binary-size(body_size), tail::binary>> = data

    body_chunks =
      for <<chunk::binary-size(16) <- body>> do
        chunk
      end

    {body_chunks, tail}
  end

  defp mix_tail(<<>>, h1, h2), do: {h1, h2}

  defp mix_tail(tail, h1, h2) do
    bytes = :binary.bin_to_list(tail)
    {k1_bytes, k2_bytes} = Enum.split(bytes, 8)

    h2 =
      case k2_bytes do
        [] ->
          h2

        _ ->
          k2 =
            k2_bytes
            |> little_endian_integer()
            |> mul64(@c2)
            |> rotl64(33)
            |> mul64(@c1)

          bxor(h2, k2)
      end

    h1 =
      case k1_bytes do
        [] ->
          h1

        _ ->
          k1 =
            k1_bytes
            |> little_endian_integer()
            |> mul64(@c1)
            |> rotl64(31)
            |> mul64(@c2)

          bxor(h1, k1)
      end

    {h1, h2}
  end

  defp finalize_hash(h1, h2, length) do
    h1 = bxor(h1, length) &&& @mask_64
    h2 = bxor(h2, length) &&& @mask_64

    h1 = add64(h1, h2)
    h2 = add64(h2, h1)

    h1 = fmix64(h1)
    h2 = fmix64(h2)

    h1 = add64(h1, h2)
    h2 = add64(h2, h1)

    {h1, h2}
  end

  defp fmix64(value) do
    value = bxor(value, value >>> 33)
    value = mul64(value, @fmix_1)
    value = bxor(value, value >>> 33)
    value = mul64(value, @fmix_2)
    bxor(value, value >>> 33) &&& @mask_64
  end

  defp mul64(left, right), do: left * right &&& @mask_64
  defp add64(left, right), do: left + right &&& @mask_64

  defp rotl64(value, bits) do
    ((value <<< bits) ||| (value >>> (64 - bits))) &&& @mask_64
  end

  defp little_endian_integer(bytes) do
    bytes
    |> Enum.with_index()
    |> Enum.reduce(0, fn {byte, index}, acc ->
      acc ||| (byte <<< (index * 8))
    end)
  end
end
