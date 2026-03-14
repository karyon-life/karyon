defmodule Rhizome.Native do
  @moduledoc """
  Low-level FFI bridge to the Rust Organelles.
  """
  use Rustler,
    otp_app: :rhizome,
    crate: "rhizome_nif"

  # NIFs
  def create_pointer(_id), do: :erlang.nif_error(:nif_not_loaded)
  def get_pointer_id(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def memgraph_query(_query), do: :erlang.nif_error(:nif_not_loaded)
  def xtdb_submit(_id, _data), do: :erlang.nif_error(:nif_not_loaded)
  def optimize_graph(), do: :erlang.nif_error(:nif_not_loaded)
  def weaken_edge(_id), do: :erlang.nif_error(:nif_not_loaded)
end
