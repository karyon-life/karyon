defmodule Sensory.Skin do
  @moduledoc """
  Generic protocol-discovery layer for opaque text and binary payloads.
  """

  alias Sensory.Perimeter

  @default_threshold 2
  @default_window 2

  def discover_payload(payload, opts \\ []) do
    surface = Keyword.get(opts, :surface, infer_surface(payload))
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    window = Keyword.get(opts, :window, @default_window)
    memory_module = Keyword.get(opts, :memory_module, Application.get_env(:sensory, :memory_module, Rhizome.Memory))

    with {:ok, _policy} <- Perimeter.validate_ingestion(%{organ: :skin, surface: surface, transport: :raw_socket}),
         {:ok, segments, encoding} <- segment_payload(payload, surface),
         {:ok, patterns} <- detect_patterns(segments, threshold, window),
         {:ok, persisted} <- persist_patterns(patterns, encoding, threshold, memory_module) do
      {:ok,
       %{
         surface: surface,
         encoding: encoding,
         threshold: threshold,
         pooled_patterns: persisted
       }}
    end
  end

  defp infer_surface(payload) when is_binary(payload) do
    if String.valid?(payload), do: :protocol_frame, else: :binary_payload
  end

  defp segment_payload(payload, :protocol_frame) when is_binary(payload) do
    segments =
      payload
      |> String.split(~r/[^[:alnum:]_]+/, trim: true)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))

    if length(segments) >= 2, do: {:ok, segments, "opaque_text"}, else: {:error, :insufficient_structure}
  end

  defp segment_payload(payload, :binary_payload) when is_binary(payload) do
    segments =
      payload
      |> :binary.bin_to_list()
      |> Enum.map(&Integer.to_string(&1, 16) |> String.pad_leading(2, "0"))

    if length(segments) >= 2, do: {:ok, segments, "opaque_binary"}, else: {:error, :insufficient_structure}
  end

  defp segment_payload(_payload, _surface), do: {:error, :invalid_skin_payload}

  defp detect_patterns(segments, threshold, window) do
    patterns =
      segments
      |> Enum.chunk_every(window, 1, :discard)
      |> Enum.map(fn chunk -> Enum.join(chunk, "->") end)
      |> Enum.frequencies()
      |> Enum.filter(fn {_signature, count} -> count >= threshold end)
      |> Enum.sort_by(fn {signature, count} -> {-count, signature} end)
      |> Enum.map(fn {signature, count} ->
        %{
          signature: signature,
          occurrences: count,
          source_types: String.split(signature, "->", parts: 2)
        }
      end)

    {:ok, patterns}
  end

  defp persist_patterns(patterns, encoding, threshold, memory_module) do
    persisted =
      Enum.map(patterns, fn pattern ->
        spec = %{
          language: encoding,
          pool_type: "opaque_structure",
          source_types: pattern.source_types,
          occurrences: pattern.occurrences
        }

        case memory_module.persist_pooled_pattern(spec) do
          {:ok, result} ->
            {:ok,
             %{
               pattern_id: result.pattern_id,
               signature: pattern.signature,
               occurrences: pattern.occurrences,
               threshold: threshold,
               source_types: pattern.source_types
             }}

          {:error, reason} ->
            {:error, {spec, reason}}
        end
      end)

    case Enum.find(persisted, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(persisted, fn {:ok, pattern} -> pattern end)}
      {:error, reason} -> {:error, reason}
    end
  end
end
