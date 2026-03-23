defmodule Sensory.Perimeter do
  @moduledoc """
  Defines the explicit sensory perimeter for Karyon.
  Only declared organ/surface/transport combinations are allowed to ingest data.
  """

  @contract %{
    tabula_rasa: %{
      description: "continuous raw-byte linguistic intake without parser priors",
      surfaces: %{
        continuous_byte_stream: [:zeromq, :raw_socket]
      }
    }
  }

  def contract, do: @contract

  def allowed_organs do
    @contract
    |> Map.keys()
    |> Enum.sort()
  end

  def allowed_surfaces do
    @contract
    |> Enum.flat_map(fn {_organ, spec} -> spec.surfaces |> Map.keys() end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def validate_ingestion(spec) when is_map(spec) do
    organ = normalize_atom(Map.get(spec, :organ) || Map.get(spec, "organ"))
    surface = normalize_atom(Map.get(spec, :surface) || Map.get(spec, "surface"))
    transport = normalize_atom(Map.get(spec, :transport) || Map.get(spec, "transport"))

    cond do
      organ not in allowed_organs() ->
        {:error, {:unsupported_sensory_organ, organ}}

      surface not in allowed_surfaces() ->
        {:error, {:unsupported_ingest_surface, surface}}

      not allowed_surface_for_organ?(organ, surface) ->
        {:error, {:surface_not_allowed_for_organ, organ, surface}}

      not allowed_transport?(organ, surface, transport) ->
        {:error, {:transport_not_allowed_for_surface, organ, surface, transport}}

      true ->
        {:ok, %{organ: organ, surface: surface, transport: transport}}
    end
  end

  def validate_ingestion(_spec), do: {:error, :invalid_ingestion_spec}

  defp allowed_surface_for_organ?(organ, surface) do
    organ
    |> organ_surfaces()
    |> Map.has_key?(surface)
  end

  defp allowed_transport?(organ, surface, transport) do
    organ
    |> organ_surfaces()
    |> Map.get(surface, [])
    |> Enum.member?(transport)
  end

  defp organ_surfaces(organ) do
    @contract
    |> Map.get(organ, %{})
    |> Map.get(:surfaces, %{})
  end

  defp normalize_atom(value) when is_atom(value), do: value

  defp normalize_atom(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]/, "_")
    |> case do
      "" -> nil
      normalized -> String.to_atom(normalized)
    end
  end

  defp normalize_atom(_value), do: nil
end
