defmodule Core.YamlParserTest do
  use ExUnit.Case, async: true
  alias Core.YamlParser

  @valid_yaml "/tmp/valid_dna.yml"
  @invalid_yaml "/tmp/invalid_dna.yml"
  @non_existent_file "/tmp/ghost_dna.yml"

  setup_all do
    File.write!(@valid_yaml, "cell_type: stem\nallowed_actions: []")
    File.write!(@invalid_yaml, "cell_type: : stem: invalid: yaml")
    
    on_exit(fn ->
      File.rm(@valid_yaml)
      File.rm(@invalid_yaml)
    end)
    :ok
  end

  test "transcribe! parses valid YAML to map" do
    result = YamlParser.transcribe!(@valid_yaml)
    assert is_map(result)
    assert result["cell_type"] == "stem"
  end

  test "transcribe! crashes on invalid YAML" do
    assert_raise YamlElixir.ParsingError, fn ->
      YamlParser.transcribe!(@invalid_yaml)
    end
  end

  test "transcribe! crashes on non-existent file" do
    assert_raise YamlElixir.FileNotFoundError, fn ->
      YamlParser.transcribe!(@non_existent_file)
    end
  end
end
