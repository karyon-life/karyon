defmodule Core.Engram do
  @moduledoc """
  Engram management logic.
  Handles serialization of the Rhizome graph into portable topological engrams.
  """

  alias Rhizome.Native
  require Logger

  @engram_path "priv/engrams/"
  @engram_version 1
  @engram_format "karyon.engram.v1"

  @doc """
  Exports the current Rhizome state to a versioned, compressed engram file.
  """
  def capture(name) when is_binary(name) do
    Logger.info("[Engram] Capturing topological state as: #{name}")

    with :ok <- validate_name(name),
         {:ok, rows} <- Native.memgraph_query(capture_query()),
         {:ok, envelope} <- build_engram(name, rows),
         {:ok, binary} <- encode_engram(envelope),
         path <- engram_file_path(name),
         :ok <- File.mkdir_p(@engram_path),
         :ok <- File.write(path, binary) do
      Logger.info("[Engram] Engram saved to #{path} (#{byte_size(binary)} bytes)")
      {:ok, path}
    end
  end

  def capture(_name), do: {:error, :invalid_engram_name}

  @doc """
  Injects an engram's topological state into the local Rhizome.
  """
  def inject(name) when is_binary(name) do
    path = engram_file_path(name)
    Logger.info("[Engram] Injecting topological state from: #{path}")

    with :ok <- validate_name(name),
         true <- File.exists?(path) or {:error, :engram_not_found},
         {:ok, binary} <- File.read(path),
         {:ok, envelope} <- decode_engram(binary),
         :ok <- validate_engram(envelope),
         :ok <- inject_nodes(envelope["nodes"]),
         :ok <- inject_edges(envelope["edges"]) do
      Logger.info("[Engram] Injection complete.")
      :ok
    end
  end

  def inject(_name), do: {:error, :invalid_engram_name}

  defp capture_query do
    """
    MATCH (n)-[r]->(m)
    RETURN
      labels(n) AS source_labels,
      properties(n) AS source_props,
      type(r) AS rel_type,
      properties(r) AS rel_props,
      labels(m) AS target_labels,
      properties(m) AS target_props
    """
  end

  defp build_engram(name, rows) when is_list(rows) do
    with {:ok, {nodes, edges}} <- normalize_rows(rows),
         digest <- compute_digest(nodes, edges) do
      {:ok,
       %{
         "engram_version" => @engram_version,
         "format" => @engram_format,
         "name" => name,
         "captured_at" => System.system_time(:second),
         "node_count" => length(nodes),
         "edge_count" => length(edges),
         "nodes" => nodes,
         "edges" => edges,
         "digest" => digest
       }}
    end
  end

  defp build_engram(_name, _rows), do: {:error, :invalid_engram_rows}

  defp normalize_rows(rows) do
    Enum.reduce_while(rows, {:ok, {%{}, []}}, fn row, {:ok, {nodes, edges}} ->
      with {:ok, source} <- normalize_node(row["source_props"], row["source_labels"]),
           {:ok, target} <- normalize_node(row["target_props"], row["target_labels"]),
           {:ok, edge} <- normalize_edge(row["rel_type"], row["rel_props"], source["id"], target["id"]) do
        updated_nodes =
          nodes
          |> Map.put(source["id"], source)
          |> Map.put(target["id"], target)

        {:cont, {:ok, {updated_nodes, [edge | edges]}}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, {nodes, edges}} ->
        {:ok,
         {nodes |> Map.values() |> Enum.sort_by(& &1["id"]),
          edges |> Enum.reverse() |> Enum.uniq()}}

      error ->
        error
    end
  end

  defp normalize_node(props, labels) when is_map(props) and is_list(labels) do
    with {:ok, id} <- extract_entity_id(props) do
      {:ok,
       %{
         "id" => id,
         "labels" => Enum.map(labels, &sanitize_label/1),
         "properties" => stringify_map_keys(props)
       }}
    end
  end

  defp normalize_node(_props, _labels), do: {:error, :invalid_engram_node}

  defp normalize_edge(type, props, source_id, target_id)
       when is_binary(type) and is_map(props) and is_binary(source_id) and is_binary(target_id) do
    {:ok,
     %{
       "type" => sanitize_label(type),
       "source_id" => source_id,
       "target_id" => target_id,
       "properties" => stringify_map_keys(props)
     }}
  end

  defp normalize_edge(_type, _props, _source_id, _target_id), do: {:error, :invalid_engram_edge}

  defp encode_engram(envelope) do
    with {:ok, json} <- Jason.encode(envelope) do
      {:ok, :zlib.gzip(json)}
    end
  end

  defp decode_engram(binary) when is_binary(binary) do
    with {:ok, json} <- gunzip(binary),
         {:ok, envelope} <- Jason.decode(json) do
      {:ok, envelope}
    else
      {:error, _reason} -> {:error, :invalid_engram_payload}
      _ -> {:error, :invalid_engram_payload}
    end
  end

  defp validate_engram(%{
         "engram_version" => @engram_version,
         "format" => @engram_format,
         "nodes" => nodes,
         "edges" => edges,
         "digest" => digest
       })
       when is_list(nodes) and is_list(edges) and is_binary(digest) do
    if digest == compute_digest(nodes, edges) do
      :ok
    else
      {:error, :engram_digest_mismatch}
    end
  end

  defp validate_engram(_payload), do: {:error, :invalid_engram_schema}

  defp inject_nodes(nodes) do
    Enum.reduce_while(nodes, :ok, fn node, :ok ->
      query = node_merge_query(node)

      case Native.memgraph_query(query) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp inject_edges(edges) do
    Enum.reduce_while(edges, :ok, fn edge, :ok ->
      query = edge_merge_query(edge)

      case Native.memgraph_query(query) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp node_merge_query(%{"id" => id, "labels" => labels, "properties" => properties}) do
    labels_fragment =
      labels
      |> Enum.reject(&(&1 in ["", "KNOWLEDGE_LINK"]))
      |> Enum.map_join("", &":#{&1}")

    """
    MERGE (n#{labels_fragment} {id: #{cypher_string(id)}})
    SET n += #{cypher_map(Map.put(properties, "id", id))}
    """
  end

  defp edge_merge_query(%{
         "type" => type,
         "source_id" => source_id,
         "target_id" => target_id,
         "properties" => properties
       }) do
    """
    MATCH (source {id: #{cypher_string(source_id)}}), (target {id: #{cypher_string(target_id)}})
    MERGE (source)-[edge:#{sanitize_label(type)}]->(target)
    SET edge += #{cypher_map(properties)}
    """
  end

  defp compute_digest(nodes, edges) do
    payload = Jason.encode!(%{"nodes" => nodes, "edges" => edges})
    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  defp extract_entity_id(%{"id" => id}) when is_binary(id) and id != "", do: {:ok, id}
  defp extract_entity_id(%{"id" => id}) when is_integer(id), do: {:ok, Integer.to_string(id)}
  defp extract_entity_id(_entity), do: {:error, :missing_entity_id}

  defp validate_name(name) do
    if Regex.match?(~r/^[A-Za-z0-9_-]+$/, name) do
      :ok
    else
      {:error, :invalid_engram_name}
    end
  end

  defp engram_file_path(name), do: Path.join(@engram_path, "#{name}.engram")

  defp gunzip(binary) do
    try do
      {:ok, :zlib.gunzip(binary)}
    rescue
      _ -> {:error, :invalid_engram_payload}
    end
  end

  defp stringify_map_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {to_string(key), stringify_map_keys(value)}
      {key, value} when is_list(value) -> {to_string(key), Enum.map(value, &stringify_nested/1)}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp stringify_nested(value) when is_map(value), do: stringify_map_keys(value)
  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value

  defp sanitize_label(label) do
    label
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_]/, "_")
    |> case do
      "" -> "GraphEntity"
      sanitized -> sanitized
    end
  end

  defp cypher_map(map) when map == %{}, do: "{}"

  defp cypher_map(map) when is_map(map) do
    entries =
      map
      |> Enum.map(fn {key, value} -> "#{sanitize_property_key(key)}: #{cypher_value(value)}" end)
      |> Enum.join(", ")

    "{#{entries}}"
  end

  defp cypher_list(list) do
    values = Enum.map_join(list, ", ", &cypher_value/1)
    "[#{values}]"
  end

  defp cypher_value(value) when is_binary(value), do: cypher_string(value)
  defp cypher_value(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp cypher_value(true), do: "true"
  defp cypher_value(false), do: "false"
  defp cypher_value(nil), do: "null"
  defp cypher_value(value) when is_list(value), do: cypher_list(value)
  defp cypher_value(value) when is_map(value), do: cypher_map(value)
  defp cypher_value(value), do: value |> to_string() |> cypher_string()

  defp cypher_string(value) do
    escaped =
      value
      |> String.replace("\\", "\\\\")
      |> String.replace("'", "\\'")

    "'#{escaped}'"
  end

  defp sanitize_property_key(key) do
    key
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_]/, "_")
  end
end
