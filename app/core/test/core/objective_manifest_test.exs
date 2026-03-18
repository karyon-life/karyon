defmodule Core.ObjectiveManifestTest do
  use ExUnit.Case

  alias Core.ObjectiveManifest
  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Attractor
  alias Core.Plan.Step

  defmodule MemoryStub do
    def submit_objective_projection(document) do
      send(self(), {:objective_projection, document})
      {:ok, %{id: "objective_projection:test"}}
    end
  end

  setup do
    root_dir = Path.join(System.tmp_dir!(), "karyon-objectives-#{System.unique_integer([:positive])}")
    workspace_dir = Path.join(System.tmp_dir!(), "karyon-workspace-#{System.unique_integer([:positive])}")
    original_root = Application.get_env(:core, :objectives_root)
    original_memory = Application.get_env(:core, :memory_module)
    original_sovereignty = Application.get_env(:core, :sovereignty)

    File.mkdir_p!(root_dir)
    File.mkdir_p!(workspace_dir)
    Application.put_env(:core, :objectives_root, root_dir)
    Application.put_env(:core, :memory_module, MemoryStub)

    on_exit(fn ->
      if original_root, do: Application.put_env(:core, :objectives_root, original_root), else: Application.delete_env(:core, :objectives_root)
      if original_memory, do: Application.put_env(:core, :memory_module, original_memory), else: Application.delete_env(:core, :memory_module)
      if original_sovereignty, do: Application.put_env(:core, :sovereignty, original_sovereignty), else: Application.delete_env(:core, :sovereignty)
      File.rm_rf(root_dir)
      File.rm_rf(workspace_dir)
    end)

    {:ok, root_dir: root_dir, workspace_dir: workspace_dir}
  end

  test "load_manifests/1 ingests objective manifests and merges workspace sovereignty", %{root_dir: root_dir, workspace_dir: workspace_dir} do
    File.write!(
      Path.join(root_dir, "workspace-objective.yml"),
      """
      id: workspace-objective
      workspace_match:
        - #{workspace_dir}
      hard_mandates:
        preserve_homeostasis: 1.4
      soft_values:
        safety: 1.25
      evolving_needs:
        continuity: 1.1
      objective_priors:
        repair: 1.3
      precedence:
        hard_mandates: 1.5
        soft_values: 1.2
        evolving_needs: 1.1
      preferred_attractors:
        - repair-attractor
      """
    )

    assert {:ok, [manifest]} = ObjectiveManifest.load_manifests(root_dir)
    assert manifest.id == "workspace-objective"
    assert manifest.workspace_match == [workspace_dir]
    assert manifest.preferred_attractors == ["repair-attractor"]

    assert {:ok, sovereignty} = ObjectiveManifest.sovereignty_for_workspace(workspace_dir)
    assert sovereignty.manifest_ids == ["workspace-objective"]
    assert_in_delta sovereignty.hard_mandates["preserve_homeostasis"], 1.4, 1.0e-6
    assert_in_delta sovereignty.soft_values["safety"], 1.25, 1.0e-6
    assert_in_delta sovereignty.evolving_needs["continuity"], 1.1, 1.0e-6
    assert_in_delta sovereignty.objective_priors["repair"], 1.3, 1.0e-6
  end

  test "rank_attractors/3 changes attractor order when objective weights change", %{root_dir: root_dir, workspace_dir: workspace_dir} do
    File.write!(
      Path.join(root_dir, "workspace-objective.yml"),
      """
      id: workspace-objective
      workspace_match:
        - #{workspace_dir}
      objective_priors:
        repair: 1.4
        exploration: 0.3
      preferred_attractors:
        - repair-attractor
      """
    )

    attractors = [
      %Attractor{
        id: "repair-attractor",
        kind: "SuperNode",
        properties: %{},
        target_state: %AbstractState{
          entity: "repair-attractor",
          phase: "target",
          summary: "target_state:repair-attractor",
          attributes: %{},
          needs: %{},
          values: %{"safety" => 1.0},
          objective_priors: %{"repair" => 1.0}
        },
        objective_priors: %{"repair" => 1.0},
        needs: %{},
        values: %{"safety" => 1.0}
      },
      %Attractor{
        id: "explore-attractor",
        kind: "SuperNode",
        properties: %{},
        target_state: %AbstractState{
          entity: "explore-attractor",
          phase: "target",
          summary: "target_state:explore-attractor",
          attributes: %{},
          needs: %{"exploration" => 1.0},
          values: %{"learning" => 1.0},
          objective_priors: %{"exploration" => 1.0}
        },
        objective_priors: %{"exploration" => 1.0},
        needs: %{"exploration" => 1.0},
        values: %{"learning" => 1.0}
      }
    ]

    assert {:ok, ranked} = ObjectiveManifest.rank_attractors(attractors, workspace_dir)
    assert hd(ranked).attractor.id == "repair-attractor"
    assert hd(ranked).score > List.last(ranked).score
  end

  test "project_workspace_plan/3 writes .nexical/plan.yml and persists objective projection", %{root_dir: root_dir, workspace_dir: workspace_dir} do
    File.write!(
      Path.join(root_dir, "workspace-objective.yml"),
      """
      id: workspace-objective
      workspace_match:
        - #{workspace_dir}
      hard_mandates:
        preserve_homeostasis: 1.4
      soft_values:
        safety: 1.25
      evolving_needs:
        continuity: 1.1
      objective_priors:
        repair: 1.3
      precedence:
        hard_mandates: 1.5
        soft_values: 1.2
        evolving_needs: 1.1
      preferred_attractors:
        - repair-attractor
      """
    )

    plan = %Plan{
      attractor: %Attractor{
        id: "repair-attractor",
        kind: "SuperNode",
        properties: %{},
        target_state: %AbstractState{
          entity: "repair-attractor",
          phase: "target",
          summary: "target_state:repair-attractor",
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
          id: "step-1",
          action: "patch_codebase",
          params: %{"vm_id" => "vm-objective"},
          predicted_state: %AbstractState{
            entity: "step-1",
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
      created_at: 1_710_000_010
    }

    assert {:ok, %{path: path, blueprint: blueprint, plan: enriched_plan}} =
             ObjectiveManifest.project_workspace_plan(plan, workspace_dir)

    assert File.exists?(path)
    assert path == Path.join([workspace_dir, ".nexical", "plan.yml"])
    assert blueprint["schema"] == "karyon.workspace-plan.v1"
    assert blueprint["objective_manifest_ids"] == ["workspace-objective"]
    assert enriched_plan.attractor.properties["workspace_root"] == workspace_dir
    assert_in_delta enriched_plan.attractor.objective_priors["preserve_homeostasis"], 2.1, 1.0e-6
    assert_in_delta enriched_plan.attractor.values["safety"], 1.5, 1.0e-6
    assert_in_delta enriched_plan.attractor.needs["continuity"], 1.21, 1.0e-6
    assert_received {:objective_projection, projection}
    assert projection["workspace_root"] == workspace_dir
    assert projection["manifest_ids"] == ["workspace-objective"]
    assert [%{"id" => "repair-attractor"}] = projection["projected_attractors"]
    assert File.read!(path) =~ "schema: \"karyon.workspace-plan.v1\""
    assert File.read!(path) =~ "objective_manifest_ids:"
  end
end
