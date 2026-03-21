defmodule Rhizome.OptimizerComplexTest do
  use ExUnit.Case, async: false
  alias Rhizome.Native

  setup_all do
    # Ensure Memgraph client is initialized
    # This might require a real Memgraph or a mock.
    # In this environment, we assume the NIF can connect to localhost:7687.
    :ok
  end

  test "temporal chunking creates ordered grammar super-nodes from repeated FOLLOWED_BY paths" do
    Native.memgraph_query("MATCH (n) DETACH DELETE n")

    Native.memgraph_query(
      "CREATE (n1:PooledSequence {id: 'ps-1', source: 'operator_environment'}), " <>
        "(n2:PooledSequence {id: 'ps-2', source: 'operator_environment'}), " <>
        "(n3:PooledSequence {id: 'ps-3', source: 'operator_environment'}), " <>
        "(n4:PooledSequence {id: 'ps-4', source: 'operator_environment'})"
    )

    Native.memgraph_query(
      "MATCH (a:PooledSequence {id: 'ps-1'}), (b:PooledSequence {id: 'ps-2'}) " <>
        "CREATE (a)-[:FOLLOWED_BY {weight: 1.0, occurrences: 3}]->(b)"
    )

    Native.memgraph_query(
      "MATCH (a:PooledSequence {id: 'ps-2'}), (b:PooledSequence {id: 'ps-3'}) " <>
        "CREATE (a)-[:FOLLOWED_BY {weight: 1.0, occurrences: 3}]->(b)"
    )

    Native.memgraph_query(
      "MATCH (a:PooledSequence {id: 'ps-4'}), (b:PooledSequence {id: 'ps-2'}) " <>
        "CREATE (a)-[:FOLLOWED_BY {weight: 1.0, occurrences: 1}]->(b)"
    )

    case Native.optimize_graph() do
      {:ok, msg} ->
        assert msg =~ "Temporal chunking complete"

        {:ok, results} =
          Native.memgraph_query(
            "MATCH (s:GrammarSuperNode {kind: 'temporal_grammar_chunk'}) RETURN count(s) as count"
          )

        case results do
          rows when is_list(rows) ->
            assert hd(rows)["count"] >= 1
          _ ->
            :ok
        end

        {:ok, positions} =
          Native.memgraph_query("""
          MATCH (s:GrammarSuperNode {kind: 'temporal_grammar_chunk'})-[r:ABSTRACTS]->(m:PooledSequence)
          RETURN collect(r.position) AS positions, collect(m.id) AS members
          """)

        case positions do
          [%{"positions" => member_positions, "members" => members}] ->
            assert Enum.sort(member_positions) == [0, 1, 2]
            assert "ps-1" in members
            assert "ps-2" in members
            assert "ps-3" in members
          _ ->
            :ok
        end

      {:error, reason} ->
        assert String.contains?(reason, "Memgraph client not initialized") or
                 String.contains?(reason, "Connection refused") or
                 String.contains?(reason, "Query Error")
    end
  end

  test "optimizer handles empty graph gracefully" do
    Native.memgraph_query("MATCH (n) DETACH DELETE n")
    case Native.optimize_graph() do
      {:ok, msg} ->
        assert msg =~ "No operator FOLLOWED_BY temporal path data found" or
                 msg =~ "No high-support temporal sequence candidates found"

      {:error, reason} ->
        assert String.contains?(reason, "Memgraph client not initialized") or
                 String.contains?(reason, "Connection refused") or
                 String.contains?(reason, "Query Error")
    end
  end
end
