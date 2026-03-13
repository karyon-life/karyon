defmodule Rhizome.Nif do
  use Rustler, otp_app: :rhizome, crate: :rhizome_nif

  @moduledoc """
  Rust Native Implemented Functions (NIF) for Phase 0 MVP.
  Provides strict, dirty-io bound offloading of syntax tree parsing and Memgraph ingestion.
  """

  @doc """
  Parses a script using tree-sitter and immediately writes the AST to Memgraph.
  """
  def parse_and_store(_script), do: :erlang.nif_error(:nif_not_loaded)
end
