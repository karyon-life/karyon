defmodule Rhizome.Memory do
  @moduledoc """
  High-level interface for Tier-0 and Tier-1 memory operations.
  """
  require Logger

  @doc """
  Executes a topology query against Memgraph (Tier-0).
  """
  def query_memgraph(query) do
    Rhizome.Native.memgraph_query(query)
  end

  @doc """
  Submits a bitemporal transaction to XTDB (Tier-1).
  """
  def submit_xtdb(id, data) do
    Rhizome.Native.xtdb_submit(id, Jason.encode!(data))
  end

  @doc """
  Persists a motor execution outcome into XTDB and projects a summary edge back into Memgraph.
  """
  def submit_execution_outcome(outcome) when is_map(outcome) do
    document =
      outcome
      |> stringify_keys()
      |> Map.put_new("recorded_at", System.system_time(:second))

    with id when is_binary(id) <- execution_outcome_id(document),
         {:ok, xtdb_result} <- submit_xtdb(id, document),
         :ok <- project_execution_outcome(document) do
      {:ok, %{id: id, xtdb: xtdb_result}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_execution_outcome}
    end
  end

  def submit_execution_outcome(_outcome), do: {:error, :invalid_execution_outcome}

  defp execution_outcome_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp execution_outcome_id(document) do
    cell_id = Map.get(document, "cell_id", "unknown_cell")
    action = Map.get(document, "action", "unknown_action")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "execution_outcome:#{cell_id}:#{action}:#{timestamp}"
  end

  defp project_execution_outcome(document) do
    cell_id = escape_cypher(Map.get(document, "cell_id", "unknown_cell"))
    outcome_id = escape_cypher(execution_outcome_id(document))
    action = escape_cypher(Map.get(document, "action", "unknown_action"))
    status = escape_cypher(Map.get(document, "status", "unknown"))
    vm_id = escape_cypher(Map.get(document, "vm_id", "none"))
    executor = escape_cypher(Map.get(document, "executor", "unknown"))
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    exit_code = normalize_numeric(document["exit_code"])

    query = """
    MERGE (c:Cell {id: '#{cell_id}'})
    MERGE (o:ExecutionOutcome {id: '#{outcome_id}'})
    SET o.action = '#{action}',
        o.status = '#{status}',
        o.executor = '#{executor}',
        o.vm_id = '#{vm_id}',
        o.exit_code = #{exit_code},
        o.recorded_at = #{timestamp}
    MERGE (c)-[:EMITTED]->(o)
    """

    case query_memgraph(query) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of execution outcome failed: #{inspect(reason)}")
        :ok
    end
  end

  defp normalize_numeric(value) when is_integer(value), do: value
  defp normalize_numeric(_value), do: -1

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {to_string(key), stringify_keys(value)}
      {key, value} when is_list(value) -> {to_string(key), Enum.map(value, &stringify_nested/1)}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp stringify_nested(value) when is_map(value), do: stringify_keys(value)
  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value

  defp escape_cypher(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  defp escape_cypher(value), do: value |> to_string() |> escape_cypher()
end
