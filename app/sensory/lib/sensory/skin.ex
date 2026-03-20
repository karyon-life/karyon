defmodule Sensory.Skin do
  @moduledoc """
  Generic raw-byte discovery layer for opaque text and binary payloads.
  """

  alias Sensory.Perimeter

  @default_threshold 2
  @default_window 5

  def discover_payload(payload, opts \\ []) do
    surface = Keyword.get(opts, :surface, infer_surface(payload))
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    window = Keyword.get(opts, :window, @default_window)
    memory_module = Keyword.get(opts, :memory_module, Application.get_env(:sensory, :memory_module, Rhizome.Memory))

    with {:ok, _policy} <- Perimeter.validate_ingestion(%{organ: :skin, surface: surface, transport: :raw_socket}),
         {:ok, bytes, encoding} <- normalize_payload(payload, surface),
         {:ok, persisted} <-
           Sensory.SpatialPooler.pool_bytes(bytes,
             window_size: window,
             threshold: threshold,
             encoding: encoding,
             memory_module: memory_module
           ) do
      {:ok,
       %{
         surface: surface,
         encoding: encoding,
         threshold: threshold,
         pooled_sequences: persisted.pooled_sequences
       }}
    end
  end

  defp infer_surface(payload) when is_binary(payload) do
    if String.valid?(payload), do: :protocol_frame, else: :binary_payload
  end

  defp normalize_payload(payload, :protocol_frame) when is_binary(payload) do
    if byte_size(payload) >= 2, do: {:ok, payload, "utf8"}, else: {:error, :insufficient_structure}
  end

  defp normalize_payload(payload, :binary_payload) when is_binary(payload) do
    if byte_size(payload) >= 2, do: {:ok, payload, "binary"}, else: {:error, :insufficient_structure}
  end

  defp normalize_payload(_payload, _surface), do: {:error, :invalid_skin_payload}
end
