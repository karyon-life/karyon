defmodule Core.Native do
  @moduledoc """
  Bridges to the metabolic_nif for hardware-level monitoring.
  """
  use Rustler, otp_app: :core, crate: "metabolic_nif"

  def read_l3_misses(), do: err()
  def read_iops(), do: err()
  def read_numa_node(), do: err()
  def read_cpu_index(), do: err()
  def set_native_mock(_iops, _l3, _fail), do: err()

  defp err(), do: :erlang.nif_error(:nif_not_loaded)
end
