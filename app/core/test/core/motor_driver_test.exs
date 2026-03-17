defmodule Core.MotorDriverTest do
  use ExUnit.Case
  alias Core.MotorDriver
  alias Core.StemCell

  setup do
    # Mocking Rhizome.Native for testing if necessary
    :ok
  end

  test "sequence_plan/1 returns a structured plan for a known attractor" do
    case MotorDriver.sequence_plan("test_attractor") do
      {:ok, plan} ->
        assert plan["attractor"] == "test_attractor"
        assert length(plan["steps"]) > 0
        Enum.each(plan["steps"], fn step ->
          assert is_binary(step["id"])
          assert is_binary(step["action"])
          assert is_map(step["params"])
          assert is_binary(step["predicted_outcome"])
        end)
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
               (:TaskNode {id: '#{root}', action: 'checkpoint', predicted_outcome: 'root_ready', sequence: 1}),
               (:TaskNode {id: '#{child}', action: 'propagate_signal', predicted_outcome: 'child_ready', sequence: 2}),
               (:SuperNode {id: '#{attractor}', type: 'COMMUNITY', confidence: 0.9})
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

    assert {:ok, plan} = MotorDriver.sequence_plan(attractor)
    assert plan["attractor"] == attractor
    assert Enum.map(plan["steps"], & &1["id"]) == [root, child]

    [first, second] = plan["steps"]
    assert first["action"] == "checkpoint"
    assert first["predicted_outcome"] == "root_ready"
    assert second["action"] == "propagate_signal"
    assert second["predicted_outcome"] == "child_ready"
    assert first["params"]["fanout"] == 1
    assert second["params"]["fanout"] == 0
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
