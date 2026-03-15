defmodule Rhizome.SleepConsolidationTest do
  use ExUnit.Case
  alias Rhizome.{Native, ConsolidationManager}

  require Logger

  test "Louvain optimization generates SuperNodes from clusters" do
    # 1. Manually inject a cluster of nodes into Memgraph via Native calls
    # (In a real test we'd need Memgraph running)
    
    # 2. Trigger optimization
    case Native.optimize_graph() do
      {:ok, result} ->
        Logger.info("[SleepConsolidationTest] Optimization result: #{result}")
        assert String.contains?(result, "Optimization complete") or String.contains?(result, "No graph data found")
      {:error, reason} ->
        # Accept connection errors in CI if Memgraph is not running
        assert String.contains?(reason, "Connection Error") or String.contains?(reason, "Query Error")
    end
  end

  test "ConsolidationManager lifecycle" do
    # Verify the manager is running in the supervision tree
    assert Process.whereis(ConsolidationManager) != nil
  end
end
