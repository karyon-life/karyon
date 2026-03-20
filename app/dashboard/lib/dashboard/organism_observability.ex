defmodule Dashboard.OrganismObservability do
  @moduledoc """
  Typed observability surface for Rhizome topology and live organism state.
  """

  @schema "karyon.organism-observability.v1"

  def report(opts \\ []) do
    memory_module = Keyword.get(opts, :memory_module, Rhizome.Memory)
    active_cells_fun = Keyword.get(opts, :active_cells_fun, &Core.EpigeneticSupervisor.active_cells/0)
    sovereignty_fun = Keyword.get(opts, :sovereignty_fun, &Core.Sovereignty.current_state/0)

    topology = topology_snapshot(memory_module)
    organism = organism_snapshot(active_cells_fun)
    graph = graph_snapshot(memory_module)
    temporal = temporal_snapshot(memory_module)
    sovereignty = sovereignty_snapshot(sovereignty_fun)

    %{
      schema: @schema,
      overall: overall_status([topology, organism, graph, temporal, sovereignty]),
      topology: topology,
      organism: organism,
      graph: graph,
      temporal: temporal,
      sovereignty: sovereignty
    }
  end

  defp topology_snapshot(memory_module) do
    case safe_apply(memory_module, :topology_contract, []) do
      contract when is_map(contract) ->
        layers =
          contract
          |> Enum.map(fn {layer, descriptor} ->
            %{
              layer: to_string(layer),
              store: descriptor.store,
              access: to_string(descriptor.access),
              operation_count: length(Map.get(descriptor, :operations, [])),
              purpose: descriptor.purpose
            }
          end)
          |> Enum.sort_by(& &1.layer)

        %{
          status: :ok,
          layer_count: length(layers),
          layers: layers
        }

      _ ->
        %{
          status: :degraded,
          layer_count: 0,
          layers: [],
          detail: "memory topology unavailable"
        }
    end
  end

  defp organism_snapshot(active_cells_fun) do
    case safe_call(active_cells_fun) do
      cells when is_list(cells) ->
        runtimes =
          cells
          |> Enum.map(&runtime_state/1)
          |> Enum.reject(&is_nil/1)

        %{
          status: :ok,
          active_cell_count: length(cells),
          active_roles: role_histogram(runtimes),
          active_statuses: status_histogram(runtimes),
          safety_critical_count: Enum.count(runtimes, &Map.get(&1, :safety_critical, false))
        }

      _ ->
        %{
          status: :degraded,
          active_cell_count: 0,
          active_roles: %{},
          active_statuses: %{},
          safety_critical_count: 0,
          detail: "active cell inventory unavailable"
        }
    end
  end

  defp graph_snapshot(memory_module) do
    %{
      status: :ok,
      prediction_error_count: working_count(memory_module, "PredictionError"),
      consolidation_supernode_count: working_count(memory_module, "GrammarSuperNode"),
      workspace_coordination_count: working_count(memory_module, "CrossWorkspaceCoordination"),
      objective_projection_count: working_count(memory_module, "ObjectiveProjection")
    }
    |> maybe_degrade_graph()
  end

  defp temporal_snapshot(memory_module) do
    recent_execution_outcome_count =
      archive_count(memory_module, %{
        "query" => %{
          "find" => ["(pull ?e [xt/id])"],
          "where" => [
            ["?e", "status", "success"]
          ]
        },
        "limit" => 25
      })

    sovereignty_event_count =
      archive_count(memory_module, %{
        "query" => %{
          "find" => ["(pull ?e [xt/id])"],
          "where" => [
            ["?e", "decision", "refuse"]
          ]
        },
        "limit" => 25
      })

    %{
      status: if(is_integer(recent_execution_outcome_count) and is_integer(sovereignty_event_count), do: :ok, else: :degraded),
      recent_execution_outcome_count: recent_execution_outcome_count || 0,
      sovereignty_event_count: sovereignty_event_count || 0
    }
  end

  defp sovereignty_snapshot(sovereignty_fun) do
    case safe_call(sovereignty_fun) do
      state when is_map(state) ->
        hard_mandates = Map.get(state, :hard_mandates, %{})
        soft_values = Map.get(state, :soft_values, %{})
        evolving_needs = Map.get(state, :evolving_needs, %{})
        objective_priors = Map.get(state, :objective_priors, %{})

        %{
          status: :ok,
          schema: Map.get(state, :schema, "karyon.sovereignty.v1"),
          top_hard_mandate: top_weight(hard_mandates),
          top_value: top_weight(soft_values),
          top_need: top_weight(evolving_needs),
          top_objective: top_weight(objective_priors)
        }

      _ ->
        %{
          status: :degraded,
          schema: "karyon.sovereignty.v1",
          top_hard_mandate: nil,
          top_value: nil,
          top_need: nil,
          top_objective: nil
        }
    end
  end

  defp working_count(memory_module, label) do
    case safe_apply(memory_module, :query_working_memory, [%{label: label, return: [:id]}]) do
      {:ok, rows} when is_list(rows) -> length(rows)
      _ -> nil
    end
  end

  defp archive_count(memory_module, query) do
    case safe_apply(memory_module, :query_archive, [query]) do
      {:ok, rows} when is_list(rows) -> length(rows)
      _ -> nil
    end
  end

  defp maybe_degrade_graph(%{prediction_error_count: nil} = graph),
    do: Map.merge(graph, %{status: :degraded, prediction_error_count: 0, consolidation_supernode_count: 0, workspace_coordination_count: 0, objective_projection_count: 0})

  defp maybe_degrade_graph(graph), do: graph

  defp role_histogram(runtimes) do
    Enum.reduce(runtimes, %{}, fn runtime, acc ->
      role = runtime |> Map.get(:role, "unknown") |> to_string()
      Map.update(acc, role, 1, &(&1 + 1))
    end)
  end

  defp status_histogram(runtimes) do
    Enum.reduce(runtimes, %{}, fn runtime, acc ->
      status = runtime |> Map.get(:status, :unknown) |> to_string()
      Map.update(acc, status, 1, &(&1 + 1))
    end)
  end

  defp runtime_state(pid) when is_pid(pid) do
    GenServer.call(pid, :get_runtime_state, 200)
  catch
    :exit, _ -> nil
  end

  defp top_weight(weights) when is_map(weights) do
    weights
    |> Enum.max_by(fn {_key, value} -> value end, fn -> nil end)
    |> case do
      nil -> nil
      {name, weight} -> %{name: to_string(name), weight: weight}
    end
  end

  defp overall_status(snapshots) do
    if Enum.all?(snapshots, &(Map.get(&1, :status) == :ok)), do: :ok, else: :degraded
  end

  defp safe_call(fun) when is_function(fun, 0) do
    fun.()
  rescue
    _ -> :error
  catch
    :exit, _ -> :error
  end

  defp safe_apply(module, function, args) do
    apply(module, function, args)
  rescue
    _ -> :error
  catch
    :exit, _ -> :error
  end
end
