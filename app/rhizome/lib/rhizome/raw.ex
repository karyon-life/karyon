defmodule Rhizome.Raw do
  use Rustler, otp_app: :rhizome, crate: :rhizome_nif

  @moduledoc false

  def create_pointer(_id), do: :erlang.nif_error(:nif_not_loaded)
  def get_pointer_id(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def memgraph_query(_query, _service_config), do: :erlang.nif_error(:nif_not_loaded)
  def xtdb_submit(_id, _data, _service_config), do: :erlang.nif_error(:nif_not_loaded)
  def xtdb_query(_query, _service_config), do: :erlang.nif_error(:nif_not_loaded)
  def optimize_graph(), do: :erlang.nif_error(:nif_not_loaded)
  def bridge_to_xtdb(_service_config), do: :erlang.nif_error(:nif_not_loaded)
  def weaken_edge(_id, _service_config), do: :erlang.nif_error(:nif_not_loaded)
end
