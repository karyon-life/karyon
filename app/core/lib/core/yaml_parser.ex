defmodule Core.YamlParser do
  @moduledoc """
  The Epigenetic transcriber. Securely parses declarative `.yml` DNA files
  into Elixir Maps, breathing structural form into identical sterile Stem Cells.
  """

  @doc """
  Reads a declarative genetics YAML file and converts it into a structured map.
  Ensures catastrophic failures halt the boot progression (apoptotic design).
  """
  def transcribe!(file_path) do
    # YamlElixir handles parsing to map.
    # The '!' explicitly instructs the beam to let it crash upon invalid YAML,
    # ensuring the Stem Cell does not boot in a partially mutated or halucinating state.
    YamlElixir.read_from_file!(file_path)
  end
end
