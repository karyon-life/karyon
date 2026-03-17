defmodule Core.MotorDriver do
  @moduledoc """
  The Motor Planning Driver.
  Translates bitemporal graph attractors into concrete sequential execution plans.
  Implements token-free Active Inference for architectural modification.
  """
  require Logger

  @doc """
  Generates a sequential plan (.yml) based on predicted state transitions.
  Traverses the Rhizome to identify the path with minimum expected free energy.
  """
  def sequence_plan(target_concept) do
    Logger.info("[MotorDriver] Sequencing plan for attractor: #{target_concept}")

    with {:ok, rows} <- Rhizome.Native.memgraph_query(super_node_query(target_concept)),
         true <- rows != [],
         {:ok, dependencies} <- fetch_causal_chain(target_concept) do
      plan = %{
        "attractor" => target_concept,
        "steps" => dependencies,
        "timestamp" => System.system_time(:second)
      }

      {:ok, plan}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :attractor_not_found}
      _ -> {:error, :attractor_not_found}
    end
  end

  @doc """
  Dispatches a plan to a specialized motor cell.
  """
  def dispatch_plan(plan, cell_pid) do
    Logger.info("[MotorDriver] Dispatching plan to motor cell: #{inspect(cell_pid)}")
    
    # Each step in the plan becomes an execution expectation
    Enum.each(plan["steps"], fn step ->
      GenServer.call(cell_pid, {:form_expectation, step["id"], step["predicted_outcome"], 0.9})
    end)

    GenServer.call(cell_pid, {:execute, "execute_plan", plan})
  end

  defp fetch_causal_chain(super_node_id) do
    query = """
    MATCH (m)-[:MEMBER_OF]->(s:SuperNode {id: '#{escape_cypher(super_node_id)}'})
    OPTIONAL MATCH (m)-[:SYNAPSE]->(n)
    WITH
      m,
      labels(m) AS labels,
      properties(m) AS props,
      count(n) AS fanout
    ORDER BY
      coalesce(m.sequence, m.order, m.priority, 0) ASC,
      coalesce(toString(m.id), toString(id(m))) ASC
    RETURN
      props,
      labels,
      fanout
    """

    with {:ok, rows} <- Rhizome.Native.memgraph_query(query) do
      steps =
        rows
        |> Enum.map(&normalize_step/1)
        |> Enum.reject(&is_nil/1)

      if steps == [] do
        {:error, :graph_plan_empty}
      else
        {:ok, steps}
      end
    end
  end

  defp normalize_step(%{"props" => props} = row) when is_map(props) do
    labels = List.wrap(row["labels"])
    fanout = row["fanout"] || 0
    action = normalize_action(props, labels, fanout)
    step_id = normalize_step_id(props)

    %{
      "id" => step_id,
      "action" => action,
      "params" => normalize_params(props, labels, fanout),
      "predicted_outcome" => normalize_predicted_outcome(props, labels, fanout)
    }
  end

  defp normalize_step(_row), do: nil

  defp normalize_action(props, labels, fanout) do
    cond do
      is_binary(props["action"]) and props["action"] != "" ->
        props["action"]

      "ASTNode" in labels and is_binary(props["type"]) ->
        "analyze_#{props["type"]}"

      "Cell" in labels and fanout > 0 ->
        "propagate_signal"

      "Cell" in labels ->
        "checkpoint"

      true ->
        "checkpoint"
    end
  end

  defp normalize_params(props, labels, fanout) do
    params =
      case props["params"] do
        map when is_map(map) -> stringify_keys(map)
        _ -> %{}
      end

    params
    |> Map.put_new("node_type", props["type"] || List.first(labels) || "graph_node")
    |> Map.put_new("fanout", fanout)
    |> maybe_put("source_id", props["id"])
  end

  defp normalize_predicted_outcome(props, labels, fanout) do
    cond do
      is_binary(props["predicted_outcome"]) and props["predicted_outcome"] != "" ->
        props["predicted_outcome"]

      is_binary(props["type"]) ->
        "graph_step:#{props["type"]}:fanout=#{fanout}"

      labels != [] ->
        "graph_step:#{Enum.join(labels, "|")}:fanout=#{fanout}"

      true ->
        "graph_step:unknown"
    end
  end

  defp normalize_step_id(props) do
    cond do
      is_binary(props["id"]) and props["id"] != "" -> props["id"]
      is_integer(props["id"]) -> Integer.to_string(props["id"])
      true -> "graph-step-#{System.unique_integer([:positive])}"
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put_new(map, key, value)

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

  defp super_node_query(target_concept) do
    "MATCH (s:SuperNode {id: '#{escape_cypher(target_concept)}'}) RETURN properties(s) AS props LIMIT 1"
  end

  defp escape_cypher(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end
end
