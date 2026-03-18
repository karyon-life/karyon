defmodule Rhizome.Native do
  @moduledoc """
  Public Rhizome contract wrapper.

  Canonical return shapes:

  - `memgraph_query/1` -> `{:ok, list(map() | term())}` for decoded query rows
  - `xtdb_query/1` -> `{:ok, list(map() | list() | term())}` for decoded query results
  - `xtdb_submit/2` -> `{:ok, %{tx_id: String.t() | nil, raw: term()}}`
  - `bridge_to_xtdb/0` -> `{:ok, %{archived_count: non_neg_integer(), message: String.t()}}`
  - `weaken_edge/1` -> `{:ok, %{message: String.t()}}`
  - `reinforce_pathway/1` -> `{:ok, %{message: String.t(), from_id: String.t(), to_id: String.t()}}`
  - `prune_pathway/1` -> `{:ok, %{message: String.t(), from_id: String.t(), to_id: String.t()}}`

  Errors are always returned as `{:error, reason}` without simulated success payloads.
  """

  alias Rhizome.Raw
  alias Rhizome.Xtdb

  def create_pointer(id), do: Raw.create_pointer(id)
  def get_pointer_id(resource), do: Raw.get_pointer_id(resource)
  def optimize_graph(), do: Raw.optimize_graph()

  def memgraph_query(query) when is_binary(query) do
    with {:ok, payload} <- Raw.memgraph_query(query, service_config_json()),
         {:ok, rows} <- decode_json(payload, :memgraph_query) do
      case rows do
        list when is_list(list) -> {:ok, list}
        other -> {:ok, [other]}
      end
    end
  end

  def xtdb_submit(id, data) when is_binary(id) do
    with {:ok, document} <- normalize_xtdb_document(data),
         {:ok, decoded} <- Xtdb.submit(id, document) do
      {:ok, %{tx_id: extract_tx_id(decoded), raw: decoded}}
    end
  end

  def xtdb_query(query) do
    Xtdb.query(query)
  end

  def bridge_to_xtdb do
    bridge_query = "MATCH (n) WHERE coalesce(n.archived, false) = false RETURN id(n) as id, properties(n) as props"

    with {:ok, rows} <- memgraph_query(bridge_query),
         {:ok, archived_count} <- archive_memgraph_rows(rows) do
      message = "Successfully bridged #{archived_count} nodes to XTDB ledger"
      {:ok, %{archived_count: archived_count, message: message}}
    end
  end

  def weaken_edge(resource) do
    with {:ok, message} <- Raw.weaken_edge(resource, service_config_json()) do
      {:ok, %{message: message}}
    end
  end

  def reinforce_pathway(spec) when is_map(spec) do
    with {:ok, normalized} <- normalize_pathway_spec(spec),
         {:ok, _rows} <- memgraph_query(reinforce_pathway_query(normalized)) do
      {:ok, pathway_result("reinforced", normalized)}
    end
  end

  def reinforce_pathway(_spec), do: {:error, :invalid_pathway}

  def prune_pathway(spec) when is_map(spec) do
    with {:ok, normalized} <- normalize_pathway_spec(spec),
         {:ok, _rows} <- memgraph_query(prune_pathway_query(normalized)) do
      {:ok, pathway_result("pruned", normalized)}
    end
  end

  def prune_pathway(_spec), do: {:error, :invalid_pathway}

  defp decode_json(payload, error_atom) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> {:error, error_atom}
    end
  end

  defp normalize_xtdb_document(data) when is_map(data), do: {:ok, stringify_map_keys(data)}

  defp normalize_xtdb_document(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} when is_map(decoded) -> {:ok, stringify_map_keys(decoded)}
      {:ok, _other} -> {:error, :invalid_xtdb_document}
      {:error, _reason} -> {:error, :invalid_xtdb_document}
    end
  end

  defp normalize_xtdb_document(_data), do: {:error, :invalid_xtdb_document}

  defp service_config_json do
    :karyon
    |> Application.get_env(:services, [])
    |> Enum.into(%{}, fn {service, options} -> {service, Enum.into(options, %{})} end)
    |> Jason.encode!()
  end

  defp extract_tx_id(%{"txId" => tx_id}) when is_binary(tx_id), do: tx_id
  defp extract_tx_id(%{"tx-id" => tx_id}) when is_binary(tx_id), do: tx_id
  defp extract_tx_id(_decoded), do: nil

  defp archive_memgraph_rows(rows) do
    Enum.reduce_while(rows, {:ok, 0}, fn row, {:ok, count} ->
      with id when is_integer(id) <- row["id"],
           props when is_map(props) <- stringify_map_keys(row["props"] || %{}),
           {:ok, _} <- Xtdb.submit("mg_#{id}", props),
           {:ok, _} <- memgraph_query("MATCH (n) WHERE id(n) = #{id} SET n.archived = true") do
        {:cont, {:ok, count + 1}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
        _ -> {:halt, {:error, :invalid_bridge_row}}
      end
    end)
  end

  defp normalize_pathway_spec(spec) do
    from_id = normalize_string(Map.get(spec, :from_id) || Map.get(spec, "from_id"))
    to_id = normalize_string(Map.get(spec, :to_id) || Map.get(spec, "to_id"))

    if from_id in [nil, ""] or to_id in [nil, ""] do
      {:error, :invalid_pathway}
    else
      {:ok,
       %{
         from_id: from_id,
         to_id: to_id,
         relationship_type:
           normalize_relationship_type(
             Map.get(spec, :relationship_type) || Map.get(spec, "relationship_type") || "PREDICTS"
           ),
         weight_delta: normalize_weight_delta(Map.get(spec, :weight_delta) || Map.get(spec, "weight_delta") || 0.1),
         trace_id: normalize_string(Map.get(spec, :trace_id) || Map.get(spec, "trace_id") || "plasticity"),
         source_step_id: normalize_string(Map.get(spec, :source_step_id) || Map.get(spec, "source_step_id") || from_id),
         target_id: normalize_string(Map.get(spec, :target_id) || Map.get(spec, "target_id") || to_id),
         event_at: System.system_time(:second)
       }}
    end
  end

  defp reinforce_pathway_query(spec) do
    """
    MERGE (from {id: '#{escape_cypher(spec.from_id)}'})
    MERGE (to {id: '#{escape_cypher(spec.to_id)}'})
    MERGE (from)-[r:#{spec.relationship_type}]->(to)
    SET r.weight = coalesce(r.weight, 1.0) + #{spec.weight_delta},
        r.status = 'reinforced',
        r.trace_id = '#{escape_cypher(spec.trace_id)}',
        r.source_step_id = '#{escape_cypher(spec.source_step_id)}',
        r.target_id = '#{escape_cypher(spec.target_id)}',
        r.last_reinforced_at = #{spec.event_at}
    RETURN r.weight AS weight
    """
  end

  defp prune_pathway_query(spec) do
    """
    MERGE (from {id: '#{escape_cypher(spec.from_id)}'})
    MERGE (to {id: '#{escape_cypher(spec.to_id)}'})
    MERGE (from)-[r:#{spec.relationship_type}]->(to)
    SET r.weight = CASE
      WHEN coalesce(r.weight, 1.0) - #{spec.weight_delta} < 0.0 THEN 0.0
      ELSE coalesce(r.weight, 1.0) - #{spec.weight_delta}
    END,
        r.status = CASE
          WHEN coalesce(r.weight, 1.0) - #{spec.weight_delta} <= 0.0 THEN 'pruned'
          ELSE 'weakened'
        END,
        r.trace_id = '#{escape_cypher(spec.trace_id)}',
        r.source_step_id = '#{escape_cypher(spec.source_step_id)}',
        r.target_id = '#{escape_cypher(spec.target_id)}',
        r.last_pruned_at = #{spec.event_at}
    RETURN r.weight AS weight
    """
  end

  defp pathway_result(message, spec) do
    %{
      message: message,
      from_id: spec.from_id,
      to_id: spec.to_id,
      relationship_type: spec.relationship_type
    }
  end

  defp stringify_map_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      normalized_key =
        case key do
          atom when is_atom(atom) -> Atom.to_string(atom)
          other -> to_string(other)
        end

      normalized_value =
        cond do
          is_map(value) -> stringify_map_keys(value)
          is_list(value) -> Enum.map(value, &stringify_nested/1)
          true -> value
        end

      {normalized_key, normalized_value}
    end)
  end

  defp stringify_nested(value) when is_map(value), do: stringify_map_keys(value)
  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: to_string(value)

  defp normalize_relationship_type(value) do
    value
    |> normalize_string()
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9_]/, "_")
    |> case do
      "" -> "PREDICTS"
      normalized -> normalized
    end
  end

  defp normalize_weight_delta(value) when is_float(value), do: value
  defp normalize_weight_delta(value) when is_integer(value), do: value * 1.0
  defp normalize_weight_delta(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> 0.1
    end
  end

  defp normalize_weight_delta(_), do: 0.1

  defp escape_cypher(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  defp escape_cypher(value), do: value |> to_string() |> escape_cypher()
end
