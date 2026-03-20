defmodule Rhizome.NifTest do
  use ExUnit.Case
  alias Rhizome.Native

  test "ResourceArc lifecycle: create and retrieve ID" do
    resource = Native.create_pointer(12345)
    assert is_reference(resource)
    assert Native.get_pointer_id(resource) == 12345
  end

  test "ResourceArc stress: creating thousands of resources" do
    # Stress test to ensure GC and Rust Drop implementation work correctly
    for i <- 1..10000 do
      _resource = Native.create_pointer(i)
      if rem(i, 1000) == 0, do: :erlang.garbage_collect()
    end
    assert true
  end

  test "weaken_edge accepts ResourceArc" do
    resource = Native.create_pointer(999)
    # This might fail if Memgraph isn't running, but we check the NIF call itself
    result = Native.weaken_edge(resource)
    case result do
      {:ok, %{message: _msg}} -> assert true
      {:error, reason} -> 
        # Connection errors are acceptable for unit testing the NIF interface
        assert String.contains?(reason, "Connection Error") or String.contains?(reason, "Query Error")
    end
  end

  test "reinforce_pathway validates pathway shape" do
    assert {:error, :invalid_pathway} = Native.reinforce_pathway(%{})
  end

  test "prune_pathway validates pathway shape" do
    assert {:error, :invalid_pathway} = Native.prune_pathway(%{})
  end

  test "prune_stdp_pathway validates STDP pathway shape" do
    assert {:error, :invalid_stdp_pathway} = Native.prune_stdp_pathway(%{})
  end

  test "build_stdp_ltd_query emits weight degradation cypher" do
    query =
      Native.build_stdp_ltd_query(%{
        sensory_id: "seq:red",
        motor_id: "motor:move_blue",
        severity: 0.4,
        trace_id: "trace:ltd",
        event_at: 1_763_958_863
      })

    assert query =~ "MATCH (s:PooledSequence"
    assert query =~ "SET r.weight = CASE"
    assert query =~ "r.status = 'depressed'"
    assert query =~ "RETURN r.weight AS weight"
  end

  test "build_stdp_apoptosis_query emits edge deletion cypher" do
    query =
      Native.build_stdp_apoptosis_query(%{
        sensory_id: "seq:red",
        motor_id: "motor:move_blue",
        severity: 0.9,
        trace_id: "trace:delete",
        event_at: 1_763_958_863
      })

    assert query =~ "MATCH (s:PooledSequence"
    assert query =~ "DELETE edge"
    assert query =~ "RETURN size(rels) AS pruned_edges"
  end
end
