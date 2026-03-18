defmodule Core.MotorDriver do
  @moduledoc """
  The Motor Planning Driver.
  Translates bitemporal graph attractors into concrete sequential execution plans.
  Implements token-free Active Inference for architectural modification.
  """
  require Logger
  alias Core.Plan
  alias Core.Plan.Attractor
  alias Core.Plan.AbstractState
  alias Core.Plan.Step

  @doc """
  Generates a sequential plan (.yml) based on predicted state transitions.
  Traverses the Rhizome to identify the path with minimum expected free energy.
  """
  def sequence_plan(%Attractor{id: target_concept} = attractor) do
    Logger.info("[MotorDriver] Sequencing plan for attractor: #{target_concept}")

    with {:ok, rows} <- Rhizome.Native.memgraph_query(super_node_query(target_concept)),
         true <- rows != [],
         {:ok, dependencies} <- fetch_causal_chain(target_concept) do
      plan = %Plan{
        attractor: merge_attractor_state(attractor, rows),
        steps: dependencies,
        transition_delta: transition_delta(dependencies),
        created_at: System.system_time(:second)
      }

      {:ok, plan}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :attractor_not_found}
      _ -> {:error, :attractor_not_found}
    end
  end

  def sequence_plan(target_concept) when is_binary(target_concept) do
    sequence_plan(%Attractor{
      id: target_concept,
      kind: "SuperNode",
      properties: %{},
      target_state: %AbstractState{
        entity: target_concept,
        phase: "target",
        summary: "target_state:#{target_concept}",
        attributes: %{},
        needs: %{},
        values: %{},
        objective_priors: %{}
      },
      objective_priors: %{},
      needs: %{},
      values: %{}
    })
  end

  @doc """
  Dispatches a plan to a specialized motor cell.
  """
  def dispatch_plan(%Plan{} = plan, cell_pid) do
    Logger.info("[MotorDriver] Dispatching plan to motor cell: #{inspect(cell_pid)}")

    # Each step in the plan becomes an execution expectation
    Enum.each(plan.steps, fn %Step{} = step ->
      GenServer.call(
        cell_pid,
        {:form_expectation, step.id, step.predicted_state.summary, 0.9,
         %{
           predicted_outcome: step.predicted_state.summary,
           objective_weight: objective_weight(plan.attractor, step),
           trace_id: expectation_trace_id(plan, step),
           source_step_id: step.id,
           source_attractor_id: plan.attractor.id,
           metadata: %{
             action: step.action,
             params: step.params,
             predicted_state: AbstractState.to_map(step.predicted_state),
             target_state: AbstractState.to_map(plan.attractor.target_state)
           }
         }}
      )
    end)

    GenServer.call(cell_pid, {:execute, "execute_plan", Plan.to_execution_payload(plan)})
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

    %Step{
      id: step_id,
      action: action,
      params: normalize_params(props, labels, fanout),
      predicted_state: normalize_predicted_state(step_id, props, labels, fanout)
    }
  end

  defp normalize_step(_row), do: nil

  defp merge_attractor_state(%Attractor{} = attractor, [%{"props" => props} | _]) when is_map(props) do
    inferred_kind =
      case props["type"] do
        type when is_binary(type) and type != "" -> type
        _ -> attractor.kind
      end

    %Attractor{
      attractor
      | kind: inferred_kind,
        properties: stringify_keys(props),
        target_state: normalize_target_state(attractor.id, inferred_kind, props),
        objective_priors: normalize_weight_map(props["objective_priors"] || %{}),
        needs: normalize_weight_map(props["needs"] || %{}),
        values: normalize_weight_map(props["values"] || %{})
    }
  end

  defp merge_attractor_state(%Attractor{} = attractor, _rows), do: attractor

  defp transition_delta(steps) do
    %{
      step_count: length(steps),
      predicted_states: Enum.map(steps, &AbstractState.to_map(&1.predicted_state)),
      predicted_outcomes: Enum.map(steps, & &1.predicted_state.summary),
      actions: Enum.map(steps, & &1.action)
    }
  end

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

  defp normalize_predicted_state(step_id, props, labels, fanout) do
    summary =
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

    %AbstractState{
      entity: step_id,
      phase: normalize_phase(props["phase"] || props["state_phase"] || props["type"] || List.first(labels) || "transition"),
      summary: summary,
      attributes:
        normalize_params(props, labels, fanout)
        |> Map.put_new("labels", labels),
      needs: normalize_weight_map(props["needs"] || %{}),
      values: normalize_weight_map(props["values"] || %{}),
      objective_priors: normalize_weight_map(props["objective_priors"] || %{})
    }
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

  defp objective_weight(%Attractor{properties: properties}, _step) when is_map(properties) do
    weight =
      properties["objective_weight"] ||
        properties[:objective_weight] ||
        properties["objective_priors"]
        |> aggregate_weight_map()

    weight || 1.0
  end

  defp objective_weight(_attractor, _step), do: 1.0

  defp expectation_trace_id(%Plan{attractor: attractor, created_at: created_at}, %Step{id: step_id}) do
    "expectation:#{attractor.id}:#{step_id}:#{created_at}"
  end

  defp normalize_target_state(attractor_id, kind, props) do
    %AbstractState{
      entity: attractor_id,
      phase: normalize_phase(props["phase"] || kind || "target"),
      summary: props["summary"] || "target_state:#{attractor_id}",
      attributes: stringify_keys(props),
      needs: normalize_weight_map(props["needs"] || %{}),
      values: normalize_weight_map(props["values"] || %{}),
      objective_priors: normalize_weight_map(props["objective_priors"] || %{})
    }
  end

  defp normalize_weight_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), normalize_weight(value)} end)
  end

  defp normalize_weight_map(_), do: %{}

  defp normalize_weight(value) when is_float(value), do: value
  defp normalize_weight(value) when is_integer(value), do: value * 1.0
  defp normalize_weight(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> 1.0
    end
  end

  defp normalize_weight(_), do: 1.0

  defp aggregate_weight_map(map) when is_map(map) do
    map
    |> Map.values()
    |> Enum.map(&normalize_weight/1)
    |> case do
      [] -> nil
      weights -> Enum.max(weights)
    end
  end

  defp aggregate_weight_map(_), do: nil

  defp normalize_phase(value) when is_binary(value), do: value
  defp normalize_phase(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_phase(value), do: to_string(value)

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
