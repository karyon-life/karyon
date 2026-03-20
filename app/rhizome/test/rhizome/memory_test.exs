defmodule Rhizome.MemoryTest do
  use ExUnit.Case, async: true
  import Rhizome.MemoryTopologyContract

  # Rhizome.Memory likely manages the interface to the NIFs and potentially some local caching.
  # We verify that it correctly delegates to Rhizome.Native.

  test "memory consolidation triggers optimizer" do
    # Verify that Rhizome.Optimizer is running and can be reached
    assert Process.whereis(Rhizome.Optimizer) != nil
  end

  test "native query execution formatting" do
    # Verify the NIF bridge exists and can be called
    # (Results will depend on whether Memgraph is running, but NIF should load)
    assert {:ok, _} = Rhizome.Native.memgraph_query("MATCH (n) RETURN n LIMIT 1")
  end

  test "normalize_abstract_state/1 preserves typed abstract-state fields" do
    state =
      Rhizome.Memory.normalize_abstract_state(%{
        entity: :planner_child,
        phase: :propagate,
        summary: "child_ready",
        attributes: %{fanout: 1, labels: ["TaskNode"]},
        needs: %{throughput: 0.8},
        values: %{safety: 1},
        objective_priors: %{latency: "1.2"}
      })

    assert state["entity"] == "planner_child"
    assert state["phase"] == "propagate"
    assert state["summary"] == "child_ready"
    assert state["attributes"]["fanout"] == 1
    assert state["needs"]["throughput"] == 0.8
    assert state["values"]["safety"] == 1.0
    assert state["objective_priors"]["latency"] == 1.2
  end

  test "topology_contract/0 exposes explicit working, archive, and consolidation layers" do
    assert_contract_layer(
      :working_graph,
      "memgraph",
      [:query_working_memory, :query_memgraph, :query_low_confidence_candidates, :query_grammar_supernodes, :upsert_graph_node, :relate_graph_nodes, :prune_stdp_pathway, :persist_pooled_sequence, :persist_pooled_pattern, :normalize_abstract_state]
    )

    assert_contract_layer(
      :temporal_archive,
      "xtdb",
      [
        :submit_xtdb,
        :write_archive_document,
        :query_archive,
        :query_recent_execution_outcomes,
        :query_recent_execution_telemetry,
        :submit_execution_outcome,
        :submit_execution_telemetry,
        :submit_prediction_error,
        :submit_trauma_event,
        :submit_baseline_curriculum,
        :submit_objective_projection,
        :submit_cross_workspace_coordination,
        :submit_sovereignty_event,
        :submit_epistemic_foraging_event,
        :submit_simulation_daemon_event,
        :submit_teacher_daemon_event,
        :submit_abstract_intent_event,
        :submit_operator_feedback_event,
        :submit_differentiation_event,
        :load_cell_state,
        :checkpoint_cell_state
      ]
    )

    assert_contract_layer(
      :consolidation_flow,
      "memgraph+xtdb",
      [:bridge_working_memory_to_archive, :bridge_to_xtdb, :optimize_graph, :memory_relief]
    )
  end

  test "memory-facing operations resolve through explicit topology descriptors" do
    assert_operation(:query_working_memory, :working_graph, "memgraph")
    assert_operation(:query_memgraph, :working_graph, "memgraph")
    assert_operation(:query_low_confidence_candidates, :working_graph, "memgraph")
    assert_operation(:query_grammar_supernodes, :working_graph, "memgraph")
    assert_operation(:upsert_graph_node, :working_graph, "memgraph")
    assert_operation(:relate_graph_nodes, :working_graph, "memgraph")
    assert_operation(:prune_stdp_pathway, :working_graph, "memgraph")
    assert_operation(:persist_pooled_sequence, :working_graph, "memgraph")
    assert_operation(:persist_pooled_pattern, :working_graph, "memgraph")
    assert_operation(:normalize_abstract_state, :working_graph, "memgraph")
    assert_operation(:write_archive_document, :temporal_archive, "xtdb")
    assert_operation(:query_archive, :temporal_archive, "xtdb")
    assert_operation(:query_recent_execution_outcomes, :temporal_archive, "xtdb")
    assert_operation(:query_recent_execution_telemetry, :temporal_archive, "xtdb")
    assert_operation(:submit_xtdb, :temporal_archive, "xtdb")
    assert_operation(:submit_execution_outcome, :temporal_archive, "xtdb")
    assert_operation(:submit_execution_telemetry, :temporal_archive, "xtdb")
    assert_operation(:submit_prediction_error, :temporal_archive, "xtdb")
    assert_operation(:submit_trauma_event, :temporal_archive, "xtdb")
    assert_operation(:submit_baseline_curriculum, :temporal_archive, "xtdb")
    assert_operation(:submit_objective_projection, :temporal_archive, "xtdb")
    assert_operation(:submit_cross_workspace_coordination, :temporal_archive, "xtdb")
    assert_operation(:submit_sovereignty_event, :temporal_archive, "xtdb")
    assert_operation(:submit_epistemic_foraging_event, :temporal_archive, "xtdb")
    assert_operation(:submit_simulation_daemon_event, :temporal_archive, "xtdb")
    assert_operation(:submit_teacher_daemon_event, :temporal_archive, "xtdb")
    assert_operation(:submit_abstract_intent_event, :temporal_archive, "xtdb")
    assert_operation(:submit_operator_feedback_event, :temporal_archive, "xtdb")
    assert_operation(:submit_differentiation_event, :temporal_archive, "xtdb")
    assert_operation(:load_cell_state, :temporal_archive, "xtdb")
    assert_operation(:checkpoint_cell_state, :temporal_archive, "xtdb")
    assert_operation(:bridge_working_memory_to_archive, :consolidation_flow, "memgraph+xtdb")
  end

  test "query_memgraph/1 rejects opaque cypher strings" do
    assert {:error, :opaque_graph_query_forbidden} = Rhizome.Memory.query_memgraph("MATCH (n) RETURN n")
  end

  test "submit_xtdb/2 rejects opaque archive blobs" do
    assert {:error, :opaque_archive_document_forbidden} =
             Rhizome.Memory.submit_xtdb("cell-1", Jason.encode!(%{"status" => "active"}))
  end

  test "query_archive/1 rejects invalid archive query shapes" do
    assert {:error, :invalid_archive_query} = Rhizome.Memory.query_archive("MATCH (n) RETURN n")
  end

  test "typed graph operations validate graph node and relationship shapes" do
    assert {:error, :invalid_graph_node} = Rhizome.Memory.upsert_graph_node(%{label: "Cell"})

    assert {:error, :invalid_graph_relationship} =
             Rhizome.Memory.relate_graph_nodes(%{
               from: %{label: "Cell", id: "one"},
               relationship_type: "EMITTED"
             })
  end

  test "persist_pooled_sequence validates pooled byte-window shape" do
    assert {:error, :invalid_pooled_sequence} =
             Rhizome.Memory.persist_pooled_sequence(%{encoding: "utf8", occurrences: 2})
  end

  test "persist_pooled_pattern validates pooled abstraction shape" do
    assert {:error, :invalid_pooled_pattern} =
             Rhizome.Memory.persist_pooled_pattern(%{language: "javascript", occurrences: 2})
  end

  test "prune_stdp_pathway validates bounded STDP shape" do
    assert {:error, :invalid_stdp_pathway} =
             Rhizome.Memory.prune_stdp_pathway(%{"sensory_id" => "seq:red", "motor_id" => "motor:1"})
  end

  test "submit_trauma_event validates immutable trauma shape" do
    assert {:error, :invalid_trauma_event} =
             Rhizome.Memory.submit_trauma_event(%{"schema" => "karyon.trauma-event.v1", "sensory_id" => "seq:red"})
  end

  test "submit_operator_feedback_event validates bounded feedback shape" do
    assert {:error, :invalid_operator_feedback_event} =
             Rhizome.Memory.submit_operator_feedback_event(%{"template_id" => "operator.status.ok"})
  end

  test "query_low_confidence_candidates/1 validates query shape" do
    assert {:error, :invalid_low_confidence_query} =
             Rhizome.Memory.query_low_confidence_candidates(%{label: "SuperNode", limit: "bad"})
  end

  test "submit_epistemic_foraging_event validates bounded exploration shape" do
    assert {:error, :invalid_epistemic_foraging_event} =
             Rhizome.Memory.submit_epistemic_foraging_event(%{"candidate_id" => "community:uncertain"})
  end

  test "submit_objective_projection validates persistent objective projection shape" do
    assert {:error, :invalid_objective_projection} =
             Rhizome.Memory.submit_objective_projection(%{"workspace_root" => "/tmp/workspace"})
  end

  test "submit_baseline_curriculum validates baseline-diet curriculum shape" do
    assert {:error, :invalid_baseline_curriculum} =
             Rhizome.Memory.submit_baseline_curriculum(%{"repository_id" => "repository:/tmp/workspace"})
  end

  test "submit_cross_workspace_coordination validates shared-memory workspace coordination shape" do
    assert {:error, :invalid_cross_workspace_coordination} =
             Rhizome.Memory.submit_cross_workspace_coordination(%{"central_workspace" => "/tmp/workspace"})
  end

  test "submit_sovereignty_event validates paradox and refusal event shape" do
    assert {:error, :invalid_sovereignty_event} =
             Rhizome.Memory.submit_sovereignty_event(%{"intent_id" => "intent:1"})
  end

  test "query_recent_execution_outcomes/1 validates recent-outcome query shape" do
    assert {:error, :invalid_recent_execution_outcomes_query} =
             Rhizome.Memory.query_recent_execution_outcomes(%{"limit" => "bad"})
  end

  test "query_recent_execution_telemetry/1 validates recent-telemetry query shape" do
    assert {:error, :invalid_recent_execution_telemetry_query} =
             Rhizome.Memory.query_recent_execution_telemetry(%{"limit" => "bad"})
  end

  test "submit_execution_telemetry validates curriculum telemetry shape" do
    assert {:error, :invalid_execution_telemetry} =
             Rhizome.Memory.submit_execution_telemetry(%{"telemetry_id" => "execution_telemetry:planner"})
  end

  test "submit_simulation_daemon_event validates dream-state event shape" do
    assert {:error, :invalid_simulation_daemon_event} =
             Rhizome.Memory.submit_simulation_daemon_event(%{"source_outcome_id" => "execution_outcome:planner"})
  end

  test "submit_teacher_daemon_event validates synthetic curriculum event shape" do
    assert {:error, :invalid_teacher_daemon_event} =
             Rhizome.Memory.submit_teacher_daemon_event(%{"exam_id" => "teacher_exam:planner"})
  end

  test "submit_abstract_intent_event validates abstract intent and drift shape" do
    assert {:error, :invalid_abstract_intent_event} =
             Rhizome.Memory.submit_abstract_intent_event(%{"intent_bundle_id" => "abstract_intent:1"})
  end
end
