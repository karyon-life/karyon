defmodule Sensory do
  @moduledoc """
  The Sensory Perimeter for Karyon.
  Deterministic extraction of Abstract Syntax Trees (AST) from codebases using Tree-sitter.
  """

  alias Sensory.Perimeter

  defdelegate perimeter_contract(), to: Perimeter, as: :contract
  defdelegate allowed_organs(), to: Perimeter
  defdelegate allowed_surfaces(), to: Perimeter
  defdelegate validate_ingestion(spec), to: Perimeter
  defdelegate parse_repository(path, opts \\ []), to: Sensory.Eyes
  defdelegate project_repository(path, opts \\ []), to: Sensory.Eyes
  defdelegate ingest_repository_baseline(path, opts \\ []), to: Sensory.BaselineDiet, as: :ingest_repository
  defdelegate normalize_event(spec), to: Sensory.Ears
  defdelegate ingest_event(spec, opts \\ []), to: Sensory.Ears
  defdelegate discover_payload(payload, opts \\ []), to: Sensory.Skin
end
