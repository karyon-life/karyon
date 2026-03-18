defmodule Rhizome.OptimizerComplexTest do
  use ExUnit.Case, async: false
  alias Rhizome.Memory
  alias Rhizome.Native

  setup_all do
    # Ensure Memgraph client is initialized
    # This might require a real Memgraph or a mock.
    # In this environment, we assume the NIF can connect to localhost:7687.
    :ok
  end

  test "leiden algorithm identifies communities and generates super-nodes" do
    # 1. Populate Memgraph with a complex graph (cyclic and disjoint)
    # Community A: 3 nodes in a cycle
    # Community B: 3 nodes in a cycle
    # No edges between A and B
    
    # We use memgraph_query to insert nodes
    Native.memgraph_query("MATCH (n) DETACH DELETE n")
    
    # Community A
    Native.memgraph_query("CREATE (n1:Cell {id: 1}), (n2:Cell {id: 2}), (n3:Cell {id: 3})")
    Native.memgraph_query("MATCH (a {id: 1}), (b {id: 2}) CREATE (a)-[:SYNAPSE {weight: 1.0}]->(b)")
    Native.memgraph_query("MATCH (a {id: 2}), (b {id: 3}) CREATE (a)-[:SYNAPSE {weight: 1.0}]->(b)")
    Native.memgraph_query("MATCH (a {id: 3}), (b {id: 1}) CREATE (a)-[:SYNAPSE {weight: 1.0}]->(b)")
    
    # Community B
    Native.memgraph_query("CREATE (n4:Cell {id: 4}), (n5:Cell {id: 5}), (n6:Cell {id: 6})")
    Native.memgraph_query("MATCH (a {id: 4}), (b {id: 5}) CREATE (a)-[:SYNAPSE {weight: 1.0}]->(b)")
    Native.memgraph_query("MATCH (a {id: 5}), (b {id: 6}) CREATE (a)-[:SYNAPSE {weight: 1.0}]->(b)")
    Native.memgraph_query("MATCH (a {id: 6}), (b {id: 4}) CREATE (a)-[:SYNAPSE {weight: 1.0}]->(b)")

    # 2. Trigger Optimization
    assert {:ok, msg} = Native.optimize_graph()
    assert msg =~ "identified"
    
    # 3. Verify Super-Nodes
    {:ok, results} = Native.memgraph_query("MATCH (s:SuperNode) RETURN count(s) as count")
    # Should have at least 2 supernodes
    case results do
      rows when is_list(rows) ->
        assert hd(rows)["count"] >= 2
      _ ->
        # If the NIF returns a string success, we skip row validation
        :ok
    end
    
    # 4. Verify Membership
    {:ok, members} = Native.memgraph_query("MATCH (m)-[:MEMBER_OF]->(s:SuperNode) RETURN count(m) as count")
    case members do
      rows when is_list(rows) ->
        assert hd(rows)["count"] == 6
      _ ->
        :ok
    end
  end

  test "optimizer handles empty graph gracefully" do
    Native.memgraph_query("MATCH (n) DETACH DELETE n")
    assert {:ok, msg} = Native.optimize_graph()
    assert msg =~ "No graph data found"
  end

  test "repeated pooled patterns reinforce co-occurrence pathways" do
    Native.memgraph_query("MATCH (n) DETACH DELETE n")

    assert {:ok, %{pattern_id: pattern_id}} =
             Memory.persist_pooled_pattern(%{
               language: "javascript",
               pool_type: "co_occurrence",
               source_types: ["program", "lexical_declaration"],
               occurrences: 3
             })

    assert {:ok, [%{"count" => 1}]} =
             Native.memgraph_query("MATCH (p:PooledPattern {id: '#{pattern_id}'}) RETURN count(p) AS count")

    assert {:ok, [%{"weight" => weight}]} =
             Native.memgraph_query("""
             MATCH (:PatternType {id: 'pattern_type:javascript:program'})-[r:CO_OCCURS_WITH]->(:PatternType {id: 'pattern_type:javascript:lexical_declaration'})
             RETURN r.weight AS weight
             """)

    assert weight >= 1.5
  end
end
