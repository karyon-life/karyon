defmodule Core.YamlParserTest do
  use ExUnit.Case, async: true

  test "transcribe! parses valid yaml" do
    dna_path = Path.expand("../../config/genetics/base_stem_cell.yml", __DIR__)
    dna = Core.YamlParser.transcribe!(dna_path)
    
    assert dna["cell_type"] == "stem_cell"
    assert is_list(dna["capabilities"])
  end

  test "transcribe! crashes on missing file" do
    assert_raise YamlElixir.FileNotFoundError, fn ->
      Core.YamlParser.transcribe!("non_existent.yml")
    end
  end
end
