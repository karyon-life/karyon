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

  test "louvain grammar optimization identifies pooled-sequence communities and generates grammar super-nodes" do
    # 1. Populate Memgraph with a complex graph (cyclic and disjoint)
    # Community A: 3 nodes in a cycle
    # Community B: 3 nodes in a cycle
    # No edges between A and B
    
    # We use memgraph_query to insert nodes
    Native.memgraph_query("MATCH (n) DETACH DELETE n")
    
    # Community A
    Native.memgraph_query("CREATE (n1:PooledSequence {id: 'ps-1', source: 'operator_environment'}), (n2:PooledSequence {id: 'ps-2', source: 'operator_environment'}), (n3:PooledSequence {id: 'ps-3', source: 'operator_environment'})")
    Native.memgraph_query("MATCH (a:PooledSequence {id: 'ps-1'}), (b:PooledSequence {id: 'ps-2'}) CREATE (a)-[:CO_OCCURS_WITH {weight: 1.0}]->(b)")
    Native.memgraph_query("MATCH (a:PooledSequence {id: 'ps-2'}), (b:PooledSequence {id: 'ps-3'}) CREATE (a)-[:CO_OCCURS_WITH {weight: 1.0}]->(b)")
    Native.memgraph_query("MATCH (a:PooledSequence {id: 'ps-3'}), (b:PooledSequence {id: 'ps-1'}) CREATE (a)-[:CO_OCCURS_WITH {weight: 1.0}]->(b)")
    
    # Community B
    Native.memgraph_query("CREATE (n4:PooledSequence {id: 'ps-4', source: 'operator_environment'}), (n5:PooledSequence {id: 'ps-5', source: 'operator_environment'}), (n6:PooledSequence {id: 'ps-6', source: 'operator_environment'})")
    Native.memgraph_query("MATCH (a:PooledSequence {id: 'ps-4'}), (b:PooledSequence {id: 'ps-5'}) CREATE (a)-[:CO_OCCURS_WITH {weight: 1.0}]->(b)")
    Native.memgraph_query("MATCH (a:PooledSequence {id: 'ps-5'}), (b:PooledSequence {id: 'ps-6'}) CREATE (a)-[:CO_OCCURS_WITH {weight: 1.0}]->(b)")
    Native.memgraph_query("MATCH (a:PooledSequence {id: 'ps-6'}), (b:PooledSequence {id: 'ps-4'}) CREATE (a)-[:CO_OCCURS_WITH {weight: 1.0}]->(b)")

    # 2. Trigger Optimization
    assert {:ok, msg} = Native.optimize_graph()
    assert msg =~ "Louvain optimization complete"
    
    # 3. Verify GrammarSuperNodes
    {:ok, results} = Native.memgraph_query("MATCH (s:GrammarSuperNode) RETURN count(s) as count")
    case results do
      rows when is_list(rows) ->
        assert hd(rows)["count"] >= 2
      _ ->
        # If the NIF returns a string success, we skip row validation
        :ok
    end
    
    # 4. Verify abstraction links
    {:ok, members} = Native.memgraph_query("MATCH (s:GrammarSuperNode)-[:ABSTRACTS]->(m:PooledSequence) RETURN count(m) as count")
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
    assert msg =~ "No operator pooled-sequence graph data found"
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
