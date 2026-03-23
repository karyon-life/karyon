defmodule Sensory.Skin do
  @moduledoc """
  Generic raw-byte discovery layer for opaque text and binary payloads.
  """

  alias Sensory.Perimeter

  def discover_payload(payload, opts \\ []) do
    surface = Keyword.get(opts, :surface, infer_surface(payload))

    with {:ok, _policy} <- Perimeter.validate_ingestion(%{organ: :skin, surface: surface, transport: :raw_socket}),
         {:ok, bytes, encoding} <- normalize_payload(payload, surface) do
      # Note: In the new architecture, sequential byte pooling is gracefully offloaded
      # to the Rust peripheral NIF, which asynchronously mints 64-bit integer tokens
      # and routes them directly to Sensory.NifRouter.
      {:ok,
       %{
         surface: surface,
         encoding: encoding,
         payload: bytes
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
