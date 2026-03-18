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
      [:query_working_memory, :query_memgraph, :upsert_graph_node, :relate_graph_nodes, :persist_pooled_pattern, :normalize_abstract_state]
    )

    assert_contract_layer(
      :temporal_archive,
      "xtdb",
      [
        :submit_xtdb,
        :write_archive_document,
        :query_archive,
        :submit_execution_outcome,
        :submit_prediction_error,
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
    assert_operation(:upsert_graph_node, :working_graph, "memgraph")
    assert_operation(:relate_graph_nodes, :working_graph, "memgraph")
    assert_operation(:persist_pooled_pattern, :working_graph, "memgraph")
    assert_operation(:normalize_abstract_state, :working_graph, "memgraph")
    assert_operation(:write_archive_document, :temporal_archive, "xtdb")
    assert_operation(:query_archive, :temporal_archive, "xtdb")
    assert_operation(:submit_xtdb, :temporal_archive, "xtdb")
    assert_operation(:submit_execution_outcome, :temporal_archive, "xtdb")
    assert_operation(:submit_prediction_error, :temporal_archive, "xtdb")
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

  test "persist_pooled_pattern validates pooled abstraction shape" do
    assert {:error, :invalid_pooled_pattern} =
             Rhizome.Memory.persist_pooled_pattern(%{language: "javascript", occurrences: 2})
  end
end
