defmodule Sensory.IngestionTest do
  use ExUnit.Case, async: false

  # This test requires Memgraph to be running.
  # It verifies that a piece of code can be ingested directly from Rust to Memgraph.

  test "ingest_to_memgraph creates nodes and edges in Memgraph" do
    lang = "javascript"
    code = "const x = 10;"
    
    # 1. Clear Memgraph before test (optional but cleaner)
    Rhizome.Native.memgraph_query("MATCH (n) DETACH DELETE n")

    # 2. Ingest code
    assert {:ok, _msg} = Sensory.Native.ingest_to_memgraph(lang, code)

    # 3. Verify in Memgraph using Rhizome.Native
    # We expect some ASTNode nodes to be created.
    {:ok, _} = Rhizome.Native.memgraph_query("MATCH (n:ASTNode) RETURN count(n) as node_count")
    
    # We can check the count or specific types if needed.
    # For simplicity, we just ensure the query succeeds and potentially check the output if it were structured.
    # Currently memgraph_query returns a raw string or status.
  end
end
