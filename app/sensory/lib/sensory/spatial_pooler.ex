defmodule Sensory.SpatialPooler do
  @moduledoc """
  Derives repeated byte-window sequences from raw sensory streams.
  """

  @default_window 5
  @default_threshold 2

  def pool_bytes(payload, opts \\ []) when is_binary(payload) do
    window_size = Keyword.get(opts, :window_size, @default_window)
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    memory_module = Keyword.get(opts, :memory_module, memory_module())
    observed_at = Keyword.get(opts, :observed_at, System.system_time(:second))
    encoding = Keyword.get(opts, :encoding, infer_encoding(payload))

    persisted =
      payload
      |> extract_windows(window_size)
      |> Enum.frequencies()
      |> Enum.filter(fn {_sequence, count} -> count >= threshold end)
      |> Enum.sort_by(fn {sequence, count} -> {-count, Base.encode16(sequence, case: :lower)} end)
      |> Enum.map(fn {sequence, count} ->
        spec = %{
          sequence: sequence,
          encoding: encoding,
          occurrences: count,
          activation_threshold: threshold,
          window_size: window_size,
          observed_at: observed_at
        }

        case memory_module.persist_pooled_sequence(spec) do
          {:ok, result} ->
            {:ok,
             %{
               sequence_id: result.sequence_id,
               signature: Base.encode16(sequence, case: :lower),
               occurrences: count,
               activation_threshold: threshold,
               window_size: window_size
             }}

          {:error, reason} ->
            {:error, {spec, reason}}
        end
      end)

    case Enum.find(persisted, &match?({:error, _}, &1)) do
      nil ->
        {:ok,
         %{
           encoding: encoding,
           ingested_bytes: byte_size(payload),
           window_size: window_size,
           threshold: threshold,
           pooled_sequences: Enum.map(persisted, fn {:ok, pattern} -> pattern end)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def extract_windows(payload, window_size \\ @default_window)

  def extract_windows(payload, window_size) when is_binary(payload) and is_integer(window_size) and window_size > 0 do
    byte_count = byte_size(payload)

    if byte_count < window_size do
      []
    else
      for offset <- 0..(byte_count - window_size) do
        binary_part(payload, offset, window_size)
      end
    end
  end

  defp memory_module do
    Application.get_env(:sensory, :memory_module, Rhizome.Memory)
  end

  defp infer_encoding(payload) when is_binary(payload) do
    if String.valid?(payload), do: "utf8", else: "binary"
  end
end
