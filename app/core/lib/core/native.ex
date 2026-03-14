defmodule Core.Native do
  @moduledoc """
  Bridges to the metabolic_nif for hardware-level monitoring.
  """
  use Rustler, otp_app: :core, crate: "metabolic_nif"

  def read_l3_misses(), do: err()
  def read_iops(), do: err()

  defp err(), do: :erlang.nif_error(:nif_not_loaded)
end
