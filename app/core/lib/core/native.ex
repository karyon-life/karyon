defmodule Core.Native do
  @moduledoc """
  Bridges to the metabolic_nif for hardware-level monitoring.
  """
  if Mix.env() == :test do
    def read_l3_misses(), do: {:ok, 100}
    def read_iops(), do: {:ok, 50}
  else
    use Rustler, otp_app: :core, crate: "metabolic_nif"
    def read_l3_misses(), do: err()
    def read_iops(), do: err()
  end

  defp err(), do: :erlang.nif_error(:nif_not_loaded)
end
