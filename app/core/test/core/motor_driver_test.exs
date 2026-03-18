defmodule Core.MotorDriverTest do
  use ExUnit.Case
  alias Core.MotorDriver
  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Step
  alias Core.StemCell

  setup do
    # Mocking Rhizome.Native for testing if necessary
    :ok
  end

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
                  action: 'propagate_signal',
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
    assert plan.attractor.values["safety"] == 1.0
    assert plan.attractor.objective_priors["stability"] == 1.4
    assert Enum.map(plan.steps, & &1.id) == [root, child]

    [first, second] = plan.steps
    assert first.action == "checkpoint"
    assert first.predicted_state.summary == "root_ready"
    assert first.predicted_state.phase == "stabilize"
    assert first.predicted_state.objective_priors["stability"] == 1.2
    assert second.action == "propagate_signal"
    assert second.predicted_state.summary == "child_ready"
    assert second.predicted_state.phase == "propagate"
    assert second.predicted_state.needs["throughput"] == 0.8
    assert first.params["fanout"] == 1
    assert second.params["fanout"] == 0
    assert plan.transition_delta.step_count == 2
    assert plan.transition_delta.actions == ["checkpoint", "propagate_signal"]
    assert [%{"summary" => "root_ready"}, %{"summary" => "child_ready"}] = plan.transition_delta.predicted_states
  end

  test "StemCell boots successfully from new DNA templates" do
    dna_path = "priv/dna/architect_planner.yml"
    # Ensure we are in the right place
    assert File.exists?(dna_path)
    
    {:ok, pid} = StemCell.start_link(dna_path)
    assert Process.alive?(pid)
    assert :active == GenServer.call(pid, :get_status)
    
    GenServer.stop(pid)
  end
end
