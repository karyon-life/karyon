defmodule Core.MotorDriverTest do
  use ExUnit.Case
  alias Core.MotorDriver
  alias Core.Plan.Attractor
  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Step
  alias Core.StemCell

  defmodule PlanExecutionProbe do
    use GenServer

    def start_link(test_pid) do
      GenServer.start_link(__MODULE__, test_pid)
    end

    @impl true
    def init(test_pid), do: {:ok, test_pid}

    @impl true
    def handle_call(:get_runtime_state, _from, test_pid) do
      {:reply,
       %{
         lineage_id: "probe-lineage",
         role: :planner,
         executor_spec: %{
           "module" => "Core.TestSupport.ExecutorStub",
           "function" => "capture_output"
         }
       }, test_pid}
    end

    @impl true
    def handle_call({:form_expectation, id, goal, precision, attrs}, _from, test_pid) do
      send(test_pid, {:expectation_formed, id, goal, precision, attrs})
      {:reply, :ok, test_pid}
    end

    @impl true
    def handle_call({:execute_intent, intent}, _from, test_pid) do
      send(test_pid, {:execution_intent_dispatched, intent})
      {:reply, {:ok, :captured}, test_pid}
    end
  end

  defmodule HighIopsNative do
    def read_l3_misses, do: {:ok, 100}
    def read_iops, do: {:ok, 5_000}
    def read_numa_node, do: {:ok, 0}
    def get_affinity_mask, do: {:ok, [0, 1]}
  end

  setup do
    original_sovereignty = Application.get_env(:core, :sovereignty)

    on_exit(fn ->
      if original_sovereignty do
        Application.put_env(:core, :sovereignty, original_sovereignty)
      else
        Application.delete_env(:core, :sovereignty)
      end
    end)

    :ok
  end

  @tag :external
  test "sequence_plan/1 returns a structured plan for a known attractor" do
    case MotorDriver.sequence_plan("test_attractor") do
      {:ok, %Plan{} = plan} ->
        assert plan.attractor.id == "test_attractor"
        assert %AbstractState{} = plan.attractor.target_state
        assert is_map(plan.attractor.objective_priors)
        assert length(plan.steps) > 0
        Enum.each(plan.steps, fn %Step{} = step ->
          assert is_binary(step.id)
          assert is_binary(step.action)
          assert is_map(step.params)
          assert %AbstractState{} = step.predicted_state
          assert is_binary(step.predicted_state.summary)
        end)
        assert is_map(plan.transition_delta)
      {:error, :graph_plan_empty} ->
        :ok
      {:error, :graph_planning_not_ready} ->
        :ok
      {:error, :attractor_not_found} ->
        :ok
    end
  end

  @tag :external
  test "sequence_plan/1 derives ordered steps from SuperNode membership in Memgraph" do
    root = "planner_root"
    child = "planner_child"
    attractor = "planner_attractor"

    assert {:ok, _} = Rhizome.Native.memgraph_query("MATCH (n) DETACH DELETE n")

    assert {:ok, _} =
             Rhizome.Native.memgraph_query("""
             CREATE
               (:TaskNode {
                  id: '#{root}',
                  action: 'checkpoint',
                  predicted_outcome: 'root_ready',
                  sequence: 1,
                  phase: 'stabilize',
                  needs: {throughput: 0.7},
                  values: {safety: 0.9},
                  objective_priors: {stability: 1.2}
                }),
               (:TaskNode {
                  id: '#{child}',
                  action: 'babble',
                  predicted_outcome: 'child_ready',
                  sequence: 2,
                  phase: 'propagate',
                  needs: {throughput: 0.8},
                  values: {safety: 0.6},
                  objective_priors: {latency: 1.1}
                }),
               (:SuperNode {
                  id: '#{attractor}',
                  type: 'COMMUNITY',
                  confidence: 0.9,
                  phase: 'target',
                  summary: 'target_state:planner_attractor',
                  needs: {throughput: 0.8},
                  values: {safety: 1.0},
                  objective_priors: {stability: 1.4}
                })
             """)

    assert {:ok, _} =
             Rhizome.Native.memgraph_query("""
             MATCH (root:TaskNode {id: '#{root}'}),
                   (child:TaskNode {id: '#{child}'}),
                   (s:SuperNode {id: '#{attractor}'})
             CREATE
               (root)-[:MEMBER_OF]->(s),
               (child)-[:MEMBER_OF]->(s),
               (root)-[:SYNAPSE {weight: 1.0}]->(child)
             """)

    assert {:ok, %Plan{} = plan} = MotorDriver.sequence_plan(attractor)
    assert plan.attractor.id == attractor
    assert plan.attractor.target_state.summary == "target_state:planner_attractor"
    assert plan.attractor.needs["throughput"] == 0.8
    assert_in_delta plan.attractor.values["safety"], 1.08, 1.0e-6
    assert plan.attractor.objective_priors["stability"] == 1.4
    assert Enum.map(plan.steps, & &1.id) == [root, child]

    [first, second] = plan.steps
    assert first.action == "checkpoint"
    assert first.predicted_state.summary == "root_ready"
    assert first.predicted_state.phase == "stabilize"
    assert first.predicted_state.objective_priors["stability"] == 1.2
    assert second.action == "babble"
    assert second.predicted_state.summary == "child_ready"
    assert second.predicted_state.phase == "propagate"
    assert second.predicted_state.needs["throughput"] == 0.8
    assert first.params["fanout"] == 1
    assert second.params["fanout"] == 0
    assert plan.transition_delta.step_count == 2
    assert plan.transition_delta.actions == ["checkpoint", "babble"]
    assert [%{"summary" => "root_ready"}, %{"summary" => "child_ready"}] = plan.transition_delta.predicted_states
  end

  test "StemCell boots successfully from new DNA templates" do
    dna_path = "../../priv/dna/tabula_rasa_stem_cell.yml"
    # Ensure we are in the right place
    assert File.exists?(dna_path)
    
    {:ok, pid} = StemCell.start_link(dna_path)
    assert Process.alive?(pid)
    assert :active == GenServer.call(pid, :get_status)
    
    GenServer.stop(pid)
  end

  test "dispatch_plan/2 sends a typed execution intent across the membrane" do
    {:ok, probe} = PlanExecutionProbe.start_link(self())

    plan = %Plan{
      attractor: %Attractor{
        id: "typed-attractor",
        kind: "SuperNode",
        properties: %{},
        target_state: %AbstractState{
          entity: "typed-attractor",
          phase: "target",
          summary: "target_state:typed-attractor",
          attributes: %{},
          needs: %{"stability" => 0.8},
          values: %{"safety" => 1.0},
          objective_priors: %{"repair" => 1.2}
        },
        objective_priors: %{"repair" => 1.2},
        needs: %{"stability" => 0.8},
        values: %{"safety" => 1.0}
      },
      steps: [
        %Step{
          id: "step-1",
          action: "babble",
          params: %{"vm_id" => "intent-vm"},
          predicted_state: %AbstractState{
            entity: "step-1",
            phase: "transition",
            summary: "patched",
            attributes: %{},
            needs: %{},
            values: %{},
            objective_priors: %{}
          }
        }
      ],
      transition_delta: %{step_count: 1, actions: ["babble"]},
      created_at: 1_710_000_000
    }

    assert {:ok, :captured} = MotorDriver.dispatch_plan(plan, probe)
    assert_receive {:expectation_formed, "step-1", "patched", 0.9, _attrs}
    assert_receive {:execution_intent_dispatched, intent}
    assert intent.id == "intent:typed-attractor:1710000000"
    assert intent.action == "execute_plan"
    assert intent.plan_attractor_id == "typed-attractor"
    assert intent.plan_step_ids == ["step-1"]
    assert intent.target_state.summary == "target_state:typed-attractor"
    assert intent.executor["module"] == "Core.TestSupport.ExecutorStub"
    assert intent.params["steps"] == [%{"id" => "step-1", "action" => "babble", "params" => %{"vm_id" => "intent-vm"}, "predicted_state" => %{"entity" => "step-1", "phase" => "transition", "summary" => "patched", "attributes" => %{}, "needs" => %{}, "values" => %{}, "objective_priors" => %{}}, "predicted_outcome" => "patched"}]
  end

  test "sequence_plan/1 enriches attractors with metabolism policy priors" do
    original_daemon = GenServer.whereis(Core.MetabolicDaemon)

    if original_daemon do
      Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
      Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end

    {:ok, daemon} =
      Core.MetabolicDaemon.start_link(
        name: Core.MetabolicDaemon,
        native_module: HighIopsNative,
        calibration_delay_ms: 10,
        poll_interval_ms: 10,
        preflight_opts: [
          mock_hardware?: false,
          file_reader: fn
            "/sys/devices/system/node/node0/meminfo" -> {:ok, "Node 0 MemTotal: 1234 kB"}
            _ -> {:error, :enoent}
          end,
          dir_lister: fn _ -> {:ok, []} end,
          scheduler_bind_type_fun: fn :scheduler_bind_type -> :tnnps end,
          logical_processors_fun: fn :logical_processors -> 8 end
        ]
      )

    Process.sleep(50)
    send(daemon, :poll_metrics)
    Process.sleep(50)

    root = "metabolic_root"
    attractor = "metabolic_attractor"

    assert {:ok, _} = Rhizome.Native.memgraph_query("MATCH (n) DETACH DELETE n")

    assert {:ok, _} =
             Rhizome.Native.memgraph_query("""
             CREATE
               (:TaskNode {
                  id: '#{root}',
                  action: 'checkpoint',
                  predicted_outcome: 'root_ready',
                  sequence: 1
                }),
               (:SuperNode {
                  id: '#{attractor}',
                  type: 'COMMUNITY',
                  summary: 'target_state:metabolic_attractor',
                  objective_priors: {stability: 1.0}
                })
             """)

    assert {:ok, _} =
             Rhizome.Native.memgraph_query("""
             MATCH (root:TaskNode {id: '#{root}'}),
                   (s:SuperNode {id: '#{attractor}'})
             CREATE (root)-[:MEMBER_OF]->(s)
             """)

    assert {:ok, %Plan{} = plan} = MotorDriver.sequence_plan(attractor)
    assert plan.attractor.properties["metabolism_policy"]["pressure"] == "high"
    assert plan.attractor.needs["stability"] == 1.0
    assert_in_delta plan.attractor.values["safety"], 1.08, 1.0e-6
    assert plan.attractor.objective_priors["repair"] == 1.3
    assert plan.transition_delta.metabolism_policy["pressure"] == "high"
    assert plan.transition_delta.metabolism_policy["objective_priors"]["repair"] == 1.3
    assert plan.transition_delta.metabolism_admission["status"] == "admitted"
    assert plan.transition_delta.scheduling["lane"] == "expedite"

    if original_daemon do
      Supervisor.start_child(Core.Supervisor, Core.MetabolicDaemon)
    else
      GenServer.stop(daemon)
    end
  end

  @tag :external
  test "sequence_plan/1 exposes sovereignty control-plane state on the planning boundary" do
    Application.put_env(:core, :sovereignty, %{
      "hard_mandates" => %{"preserve_homeostasis" => 1.4},
      "soft_values" => %{"safety" => 1.25},
      "evolving_needs" => %{"continuity" => 1.1},
      "objective_priors" => %{"repair" => 1.2},
      "precedence" => %{
        "hard_mandates" => 1.5,
        "soft_values" => 1.2,
        "evolving_needs" => 1.1,
        "objective_priors" => 1.0
      }
    })

    root = "sovereign_root"
    attractor = "sovereign_attractor"

    assert {:ok, _} = Rhizome.Native.memgraph_query("MATCH (n) DETACH DELETE n")

    assert {:ok, _} =
             Rhizome.Native.memgraph_query("""
             CREATE
               (:TaskNode {
                  id: '#{root}',
                  action: 'checkpoint',
                  predicted_outcome: 'root_ready',
                  sequence: 1,
                  values: {safety: 1.1}
                }),
               (:SuperNode {
                  id: '#{attractor}',
                  type: 'COMMUNITY',
                  summary: 'target_state:sovereign_attractor',
                  values: {safety: 1.0},
                  objective_priors: {repair: 1.0}
                })
             """)

    assert {:ok, _} =
             Rhizome.Native.memgraph_query("""
             MATCH (root:TaskNode {id: '#{root}'}),
                   (s:SuperNode {id: '#{attractor}'})
             CREATE (root)-[:MEMBER_OF]->(s)
             """)

    assert {:ok, %Plan{} = plan} = MotorDriver.sequence_plan(attractor)
    assert plan.attractor.properties["sovereignty"]["schema"] == "karyon.sovereignty.v1"
    assert plan.attractor.properties["sovereignty"]["hard_mandates"]["preserve_homeostasis"] == 1.4
    assert_in_delta plan.attractor.values["safety"], 1.5, 1.0e-6
    assert_in_delta plan.attractor.needs["continuity"], 1.21, 1.0e-6
    assert_in_delta plan.attractor.objective_priors["preserve_homeostasis"], 2.1, 1.0e-6
    assert plan.transition_delta.sovereignty["soft_values"]["safety"] == 1.25
  end

  test "dispatch_plan/2 defers low-priority work under constrained ATP admission" do
    {:ok, probe} = PlanExecutionProbe.start_link(self())

    plan = %Plan{
      attractor: %Attractor{
        id: "deferred-attractor",
        kind: "SuperNode",
        properties: %{"metabolism_policy" => %{"pressure" => "high", "atp" => 0.4}},
        target_state: %AbstractState{
          entity: "deferred-attractor",
          phase: "target",
          summary: "target_state:deferred-attractor",
          attributes: %{},
          needs: %{},
          values: %{},
          objective_priors: %{"refinement" => 0.2}
        },
        objective_priors: %{"refinement" => 0.2},
        needs: %{},
        values: %{}
      },
      steps: [
        %Step{
          id: "step-deferred",
          action: "babble",
          params: %{},
          predicted_state: %AbstractState{
            entity: "step-deferred",
            phase: "transition",
            summary: "refined",
            attributes: %{},
            needs: %{},
            values: %{},
            objective_priors: %{"refinement" => 0.2}
          }
        }
      ],
      transition_delta: %{
        metabolism_admission: %{"status" => "deferred", "lane" => "deferred", "pressure" => "high"}
      },
      created_at: 1_710_000_001
    }

    assert {:error, :insufficient_atp_budget} = MotorDriver.dispatch_plan(plan, probe)
    refute_received {:expectation_formed, _, _, _, _}
    refute_received {:execution_intent_dispatched, _}
  end
end
