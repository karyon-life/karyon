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

  @doc """
  Persists a typed prediction error into XTDB and projects a summary edge back into Memgraph.
  """
  def submit_prediction_error(prediction_error) when is_map(prediction_error) do
    document =
      prediction_error
      |> stringify_keys()
      |> Map.put_new("recorded_at", System.system_time(:second))

    with id when is_binary(id) <- prediction_error_id(document),
         {:ok, xtdb_result} <- submit_xtdb(id, document),
         :ok <- project_prediction_error(document) do
      {:ok, %{id: id, xtdb: xtdb_result}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_prediction_error}
    end
  end

  def submit_prediction_error(_prediction_error), do: {:error, :invalid_prediction_error}

  @doc """
  Loads the latest durable state snapshot for a cell lineage.
  """
  def load_cell_state(lineage_id) when is_binary(lineage_id) and lineage_id != "" do
    query = %{
      "query" => %{
        "find" => ["(pull ?e [beliefs expectations atp_metabolism status dna_path lineage_id])"],
        "where" => [["?e", "xt/id", cell_state_id(lineage_id)]]
      }
    }

    case Rhizome.Native.xtdb_query(query) do
      {:ok, [%{} = state | _]} -> {:ok, state}
      {:ok, [[%{} = state] | _]} -> {:ok, state}
      {:ok, [%{"data" => %{} = state} | _]} -> {:ok, state}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :not_found}
    end
  end

  def load_cell_state(_lineage_id), do: {:error, :invalid_lineage_id}

  @doc """
  Persists a durable state snapshot for a cell lineage.
  """
  def checkpoint_cell_state(snapshot) when is_map(snapshot) do
    document =
      snapshot
      |> stringify_keys()
      |> Map.put_new("recorded_at", System.system_time(:second))

    with lineage_id when is_binary(lineage_id) and lineage_id != "" <- Map.get(document, "lineage_id"),
         {:ok, xtdb_result} <- submit_xtdb(cell_state_id(lineage_id), document) do
      {:ok, %{id: cell_state_id(lineage_id), xtdb: xtdb_result}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_cell_state}
    end
  end

  def checkpoint_cell_state(_snapshot), do: {:error, :invalid_cell_state}

  @doc """
  Normalizes an abstract-state document so planning and telemetry can persist
  the same typed state shape at the Rhizome boundary.
  """
  def normalize_abstract_state(state) when is_map(state) do
    %{
      "entity" => to_string(Map.get(state, "entity") || Map.get(state, :entity) || "unknown"),
      "phase" => to_string(Map.get(state, "phase") || Map.get(state, :phase) || "unknown"),
      "summary" => to_string(Map.get(state, "summary") || Map.get(state, :summary) || "unknown"),
      "attributes" => stringify_keys(Map.get(state, "attributes") || Map.get(state, :attributes) || %{}),
      "needs" => normalize_weight_map(Map.get(state, "needs") || Map.get(state, :needs) || %{}),
      "values" => normalize_weight_map(Map.get(state, "values") || Map.get(state, :values) || %{}),
      "objective_priors" => normalize_weight_map(Map.get(state, "objective_priors") || Map.get(state, :objective_priors) || %{})
    }
  end

  def normalize_abstract_state(_state), do: %{}

  defp execution_outcome_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp execution_outcome_id(document) do
    cell_id = Map.get(document, "cell_id", "unknown_cell")
    action = Map.get(document, "action", "unknown_action")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "execution_outcome:#{cell_id}:#{action}:#{timestamp}"
  end

  defp prediction_error_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp prediction_error_id(document) do
    cell_id = Map.get(document, "cell_id", "unknown_cell")
    type = Map.get(document, "type", "unknown")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "prediction_error:#{cell_id}:#{type}:#{timestamp}"
  end

  defp cell_state_id(lineage_id), do: "cell_state:#{lineage_id}"

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

  defp project_prediction_error(document) do
    cell_id = escape_cypher(Map.get(document, "cell_id", "unknown_cell"))
    error_id = escape_cypher(prediction_error_id(document))
    type = escape_cypher(Map.get(document, "type", "unknown"))
    source_cell_id = escape_cypher(Map.get(document, "source_cell_id", "unknown"))
    message = escape_cypher(Map.get(document, "message", ""))
    status = escape_cypher(Map.get(document, "status", "observed"))
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    vfe = normalize_float(document["vfe"])
    atp = normalize_float(document["atp"])

    query = """
    MERGE (c:Cell {id: '#{cell_id}'})
    MERGE (p:PredictionError {id: '#{error_id}'})
    SET p.type = '#{type}',
        p.message = '#{message}',
        p.status = '#{status}',
        p.source_cell_id = '#{source_cell_id}',
        p.vfe = #{vfe},
        p.atp = #{atp},
        p.recorded_at = #{timestamp}
    MERGE (c)-[:EXPERIENCED]->(p)
    """

    case query_memgraph(query) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of prediction error failed: #{inspect(reason)}")
        :ok
    end
  end

  defp normalize_numeric(value) when is_integer(value), do: value
  defp normalize_numeric(_value), do: -1
  defp normalize_float(value) when is_float(value), do: value
  defp normalize_float(value) when is_integer(value), do: value * 1.0
  defp normalize_float(_value), do: -1.0

  defp normalize_weight_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), normalize_weight(value)} end)
  end

  defp normalize_weight_map(_), do: %{}

  defp normalize_weight(value) when is_float(value), do: value
  defp normalize_weight(value) when is_integer(value), do: value * 1.0
  defp normalize_weight(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> -1.0
    end
  end

  defp normalize_weight(_), do: -1.0

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
