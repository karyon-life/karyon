defmodule Rhizome.Native do
  use Rustler, otp_app: :rhizome, crate: :rhizome_nif

  @moduledoc """
  Rust Native Implemented Functions (NIF) for Phase 0 MVP.
  Provides strict, dirty-io bound offloading of syntax tree parsing and Memgraph ingestion.
  """

  @doc """
  Parses a script using tree-sitter and immediately writes the AST to Memgraph.
  """
  def create_pointer(_id), do: :erlang.nif_error(:nif_not_loaded)
  def get_pointer_id(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def memgraph_query(_query), do: :erlang.nif_error(:nif_not_loaded)
  def xtdb_submit(_id, _data), do: :erlang.nif_error(:nif_not_loaded)
  def optimize_graph(), do: :erlang.nif_error(:nif_not_loaded)
  def weaken_edge(_id), do: :erlang.nif_error(:nif_not_loaded)
end
