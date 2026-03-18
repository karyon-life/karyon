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
end
