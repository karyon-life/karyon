defmodule Sensory.Native do
  @moduledoc """
  NIF bridge for the Sensory layer (Tree-sitter).
  """
  use Rustler,
    otp_app: :sensory,
    crate: "sensory_nif"

  def parse_code(_lang, _code), do: :erlang.nif_error(:nif_not_loaded)
end
