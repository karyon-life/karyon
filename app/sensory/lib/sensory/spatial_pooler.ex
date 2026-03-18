defmodule Sensory.SpatialPooler do
  @moduledoc """
  Derives repeated structural co-occurrence patterns from deterministic sensory graphs.
  """

  @default_threshold 2

  def pool_code(language, code, opts \\ []) when is_binary(language) and is_binary(code) do
    with {:ok, graph} <- decode_graph(Sensory.Native.parse_to_graph(language, code)),
         {:ok, pooled} <- pool_graph(language, graph, opts) do
      {:ok, pooled}
    end
  end

  def pool_graph(language, %{"nodes" => nodes, "edges" => edges}, opts) when is_binary(language) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    memory_module = Keyword.get(opts, :memory_module, memory_module())

    node_types =
      Map.new(nodes, fn node ->
        {to_string(node["id"]), node["type"] || "unknown"}
      end)

    patterns =
      edges
      |> Enum.filter(&(&1["type"] == "CHILD"))
      |> Enum.map(fn edge ->
        {
          Map.get(node_types, to_string(edge["source"]), "unknown"),
          Map.get(node_types, to_string(edge["target"]), "unknown")
        }
      end)
      |> Enum.frequencies()
      |> Enum.filter(fn {_pair, count} -> count >= threshold end)
      |> Enum.sort_by(fn {_pair, count} -> -count end)

    persisted =
      Enum.map(patterns, fn {{parent_type, child_type}, count} ->
        spec = %{
          language: language,
          pool_type: "co_occurrence",
          source_types: [parent_type, child_type],
          occurrences: count
        }

        case memory_module.persist_pooled_pattern(spec) do
          {:ok, result} ->
            {:ok,
             %{
               pattern_id: result.pattern_id,
               signature: "#{parent_type}->#{child_type}",
               occurrences: count,
               source_types: [parent_type, child_type]
             }}

          {:error, reason} ->
            {:error, {spec, reason}}
        end
      end)

    case Enum.find(persisted, &match?({:error, _}, &1)) do
      nil ->
        {:ok,
         %{
           language: language,
           threshold: threshold,
           pooled_patterns: Enum.map(persisted, fn {:ok, pattern} -> pattern end)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def pool_graph(_language, _graph, _opts), do: {:error, :invalid_graph}

  defp decode_graph("Unsupported language"), do: {:error, :unsupported_language}

  defp decode_graph(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"nodes" => _nodes, "edges" => _edges} = graph} -> {:ok, graph}
      {:ok, _other} -> {:error, :invalid_graph}
      {:error, _reason} -> {:error, :invalid_graph}
    end
  end

  defp memory_module do
    Application.get_env(:sensory, :memory_module, Rhizome.Memory)
  end
end
