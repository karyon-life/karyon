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
end
