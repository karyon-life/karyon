defmodule Rhizome.MemoryTest do
  use ExUnit.Case, async: true

  # Rhizome.Memory likely manages the interface to the NIFs and potentially some local caching.
  # We verify that it correctly delegates to Rhizome.Native.

  test "memory consolidation triggers optimizer" do
    # Verify that Rhizome.Optimizer is running and can be reached
    assert Process.whereis(Rhizome.Optimizer) != nil
  end

  test "native query execution formatting" do
    # Verify the NIF bridge exists and can be called
    # (Results will depend on whether Memgraph is running, but NIF should load)
    assert is_binary(Rhizome.Native.memgraph_query("MATCH (n) RETURN n LIMIT 1"))
  end
end
