defmodule Sensory.QuantizerTier3Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Sensory.Quantizer

  @max_u64 0xFFFFFFFFFFFFFFFF

  property "lexical hashing is deterministic for the same token" do
    check all token <- string(:alphanumeric, min_length: 1, max_length: 64) do
      assert Quantizer.quantize(token) == Quantizer.quantize(token)
    end
  end

  property "lexical hashing returns a 64-bit integer for non-empty tokens" do
    check all token <- string(:alphanumeric, min_length: 1, max_length: 64) do
      id = Quantizer.quantize(token)

      assert is_integer(id)
      assert id >= 0
      assert id <= @max_u64
    end
  end

  property "lexical hashing avoids collisions across a generated unique corpus" do
    check all tokens <- uniq_list_of(string(:alphanumeric, min_length: 1, max_length: 32), min_length: 25, max_length: 100) do
      ids = Enum.map(tokens, &Quantizer.quantize/1)

      assert length(ids) == length(Enum.uniq(ids))
    end
  end
end
