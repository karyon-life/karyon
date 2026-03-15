defmodule Sensory.Native do
  @moduledoc """
  NIF bridge for the Sensory layer (Tree-sitter).
  """
  use Rustler,
    otp_app: :sensory,
    crate: "sensory_nif"

  def parse_code(_lang, _code), do: :erlang.nif_error(:nif_not_loaded)
  def parse_to_graph(_lang, _code), do: :erlang.nif_error(:nif_not_loaded)
  def ingest_to_memgraph(_lang, _code), do: :erlang.nif_error(:nif_not_loaded)
  def zmq_publish_tensor(_topic, _payload), do: :erlang.nif_error(:nif_not_loaded)
  def zmq_subscribe_sensory(_topic), do: :erlang.nif_error(:nif_not_loaded)
end
