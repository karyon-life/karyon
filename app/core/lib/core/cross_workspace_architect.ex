defmodule Core.CrossWorkspaceArchitect do
  @moduledoc """
  Coordinates shared-memory planning across multiple workspaces while keeping
  execution blueprints localized to each workspace limb.
  """

  alias Core.ObjectiveManifest
  alias Core.Plan

  @schema "karyon.cross-workspace-plan.v1"

  def coordinate(plan_specs, opts \\ [])

  def coordinate(plan_specs, opts) when is_list(plan_specs) do
    workspace_specs = Enum.map(plan_specs, &normalize_workspace_spec/1)

    with :ok <- validate_workspace_specs(workspace_specs),
         central_workspace <- central_workspace(workspace_specs),
         {:ok, projected} <- project_workspaces(workspace_specs, opts),
         {:ok, shared_memory} <- shared_memory_projection(projected, central_workspace, opts) do
      {:ok,
       %{
         schema: @schema,
         central_workspace: central_workspace,
         localized_plans: projected,
         shared_memory: shared_memory
       }}
    end
  end

  def coordinate(_plan_specs, _opts), do: {:error, :invalid_cross_workspace_plan}

  defp project_workspaces(workspace_specs, opts) do
    Enum.reduce_while(workspace_specs, {:ok, []}, fn spec, {:ok, acc} ->
      case ObjectiveManifest.project_workspace_plan(spec.plan, spec.workspace_root, opts) do
        {:ok, result} ->
          localized =
            result
            |> Map.put(:workspace_root, spec.workspace_root)
            |> Map.put(:role, spec.role)
            |> Map.put(:coordination_scope, spec.coordination_scope)

          {:cont, {:ok, [localized | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, localized} -> {:ok, Enum.reverse(localized)}
      error -> error
    end
  end

  defp shared_memory_projection(projected, central_workspace, opts) do
    memory_module =
      Keyword.get(opts, :memory_module, Application.get_env(:core, :memory_module, Rhizome.Memory))

    coordination_id = "cross_workspace:#{:erlang.phash2(Enum.map(projected, & &1.workspace_root))}"

    document = %{
      "id" => coordination_id,
      "schema" => @schema,
      "central_workspace" => central_workspace,
      "workspace_roots" => Enum.map(projected, & &1.workspace_root),
      "localized_plan_paths" => Enum.map(projected, & &1.path),
      "roles" => Enum.map(projected, & &1.role),
      "coordination_scopes" => Enum.map(projected, & &1.coordination_scope),
      "attractor_ids" => Enum.map(projected, & &1.plan.attractor.id),
      "recorded_at" => System.system_time(:second)
    }

    case memory_module.submit_cross_workspace_coordination(document) do
      {:ok, result} -> {:ok, Map.put(result, :document, document)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_workspace_spec(%{workspace_root: _workspace_root, plan: %Plan{}} = spec) do
    %{
      workspace_root: Path.expand(spec.workspace_root),
      role: Map.get(spec, :role, "local_limb"),
      coordination_scope: Map.get(spec, :coordination_scope, "localized_execution"),
      plan: spec.plan
    }
  end

  defp normalize_workspace_spec(%{"workspace_root" => _workspace_root, "plan" => %Plan{}} = spec) do
    %{
      workspace_root: Path.expand(spec["workspace_root"]),
      role: Map.get(spec, "role", "local_limb"),
      coordination_scope: Map.get(spec, "coordination_scope", "localized_execution"),
      plan: spec["plan"]
    }
  end

  defp normalize_workspace_spec(other), do: other

  defp validate_workspace_specs(workspace_specs) do
    cond do
      workspace_specs == [] ->
        {:error, :invalid_cross_workspace_plan}

      Enum.any?(workspace_specs, fn spec ->
        not is_map(spec) or not is_binary(Map.get(spec, :workspace_root)) or not match?(%Plan{}, Map.get(spec, :plan))
      end) ->
        {:error, :invalid_cross_workspace_plan}

      true ->
        :ok
    end
  end

  defp central_workspace(workspace_specs) do
    workspace_specs
    |> Enum.find(workspace_specs |> List.first(), fn spec -> spec.role == "central_architect" end)
    |> Map.get(:workspace_root)
  end
end
