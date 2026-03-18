defmodule Core.CrossWorkspaceArchitectTest do
  use ExUnit.Case

  alias Core.CrossWorkspaceArchitect
  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Attractor
  alias Core.Plan.Step

  defmodule MemoryStub do
    def submit_objective_projection(document) do
      send(self(), {:objective_projection, document})
      {:ok, %{id: "objective_projection:test"}}
    end

    def submit_cross_workspace_coordination(document) do
      send(self(), {:cross_workspace_coordination, document})
      {:ok, %{id: document["id"] || "cross_workspace:test"}}
    end
  end

  setup do
    root_dir = Path.join(System.tmp_dir!(), "karyon-cross-objectives-#{System.unique_integer([:positive])}")
    central_workspace = Path.join(System.tmp_dir!(), "karyon-central-#{System.unique_integer([:positive])}")
    limb_workspace = Path.join(System.tmp_dir!(), "karyon-limb-#{System.unique_integer([:positive])}")
    original_root = Application.get_env(:core, :objectives_root)
    original_memory = Application.get_env(:core, :memory_module)

    File.mkdir_p!(root_dir)
    File.mkdir_p!(central_workspace)
    File.mkdir_p!(limb_workspace)
    Application.put_env(:core, :objectives_root, root_dir)
    Application.put_env(:core, :memory_module, MemoryStub)

    on_exit(fn ->
      if original_root, do: Application.put_env(:core, :objectives_root, original_root), else: Application.delete_env(:core, :objectives_root)
      if original_memory, do: Application.put_env(:core, :memory_module, original_memory), else: Application.delete_env(:core, :memory_module)
      File.rm_rf(root_dir)
      File.rm_rf(central_workspace)
      File.rm_rf(limb_workspace)
    end)

    {:ok, root_dir: root_dir, central_workspace: central_workspace, limb_workspace: limb_workspace}
  end

  test "coordinate/2 writes localized plans for multiple workspaces and persists shared-memory coordination", %{
    root_dir: root_dir,
    central_workspace: central_workspace,
    limb_workspace: limb_workspace
  } do
    File.write!(
      Path.join(root_dir, "shared-objective.yml"),
      """
      id: shared-objective
      workspace_match:
        - #{central_workspace}
        - #{limb_workspace}
      hard_mandates:
        preserve_homeostasis: 1.4
      soft_values:
        safety: 1.2
      objective_priors:
        repair: 1.3
      preferred_attractors:
        - central-attractor
        - limb-attractor
      """
    )

    central_plan = plan_fixture("central-attractor", "step-central")
    limb_plan = plan_fixture("limb-attractor", "step-limb")

    assert {:ok, result} =
             CrossWorkspaceArchitect.coordinate([
               %{workspace_root: central_workspace, role: "central_architect", coordination_scope: "global_plan", plan: central_plan},
               %{workspace_root: limb_workspace, role: "local_limb", coordination_scope: "localized_execution", plan: limb_plan}
             ])

    assert result.schema == "karyon.cross-workspace-plan.v1"
    assert result.central_workspace == central_workspace
    assert length(result.localized_plans) == 2
    assert Enum.all?(result.localized_plans, &File.exists?(&1.path))
    assert Enum.map(result.localized_plans, & &1.workspace_root) == [central_workspace, limb_workspace]
    assert_received {:cross_workspace_coordination, coordination}
    assert coordination["central_workspace"] == central_workspace
    assert coordination["workspace_roots"] == [central_workspace, limb_workspace]
    assert coordination["roles"] == ["central_architect", "local_limb"]
  end

  test "coordinate/2 rejects invalid workspace specifications" do
    assert {:error, :invalid_cross_workspace_plan} = CrossWorkspaceArchitect.coordinate([])
    assert {:error, :invalid_cross_workspace_plan} = CrossWorkspaceArchitect.coordinate([%{workspace_root: "/tmp/x"}])
  end

  defp plan_fixture(attractor_id, step_id) do
    %Plan{
      attractor: %Attractor{
        id: attractor_id,
        kind: "SuperNode",
        properties: %{},
        target_state: %AbstractState{
          entity: attractor_id,
          phase: "target",
          summary: "target_state:#{attractor_id}",
          attributes: %{},
          needs: %{},
          values: %{},
          objective_priors: %{"repair" => 1.0}
        },
        objective_priors: %{"repair" => 1.0},
        needs: %{},
        values: %{}
      },
      steps: [
        %Step{
          id: step_id,
          action: "patch_codebase",
          params: %{"vm_id" => "#{step_id}-vm"},
          predicted_state: %AbstractState{
            entity: step_id,
            phase: "transition",
            summary: "patched",
            attributes: %{},
            needs: %{},
            values: %{},
            objective_priors: %{"repair" => 1.0}
          }
        }
      ],
      transition_delta: %{actions: ["patch_codebase"]},
      created_at: 1_710_000_040
    }
  end
end
