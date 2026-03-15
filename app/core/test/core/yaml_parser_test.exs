defmodule Core.YamlParserTest do
  use ExUnit.Case
  alias Core.YamlParser

  @valid_dna "/tmp/valid_dna.yml"
  @invalid_dna "/tmp/invalid_dna.yml"

  setup do
    File.write!(@valid_dna, """
    cell_type: motor
    synapses:
      - type: push
        bind: "tcp://127.0.0.1:0"
    """)

    File.write!(@invalid_dna, """
    cell_type: [unclosed list
    """)

    on_exit(fn ->
      File.rm(@valid_dna)
      File.rm(@invalid_dna)
    end)
  end

  test "transcribe! parses valid DNA" do
    dna = YamlParser.transcribe!(@valid_dna)
    assert dna["cell_type"] == "motor"
    assert is_list(dna["synapses"])
  end

  test "transcribe! raises for invalid YAML (apoptotic design)" do
    assert_raise YamlElixir.ParsingError, fn ->
      YamlParser.transcribe!(@invalid_dna)
    end
  end

  test "transcribe! raises for missing file" do
    assert_raise YamlElixir.FileNotFoundError, fn ->
      YamlParser.transcribe!("/tmp/non_existent.yml")
    end
  end
end
