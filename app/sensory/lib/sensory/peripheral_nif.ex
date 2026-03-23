defmodule Sensory.PeripheralNif do
  @moduledoc """
  NIF bridge to the high-speed Rust-based BPE dictionary for sensory compression
  and motor decompression.
  """
  use Rustler, otp_app: :sensory, crate: :karyon_nif, path: "../native/karyon_nif"

  @doc """
  Compresses a raw byte stream into high-level semantic tokens.
  """
  def compress_stream(_caller_pid, _binary, _pmi_threshold, _min_freq), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Recursively unpacks a high-level semantic integer into its raw binary payload.
  """
  def decompress_token(_token), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Flushes dead tokens determined to have no synaptic linkages.
  """
  def trigger_apoptosis(_token), do: :erlang.nif_error(:nif_not_loaded)
end
