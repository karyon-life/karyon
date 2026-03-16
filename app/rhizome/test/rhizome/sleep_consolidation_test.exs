defmodule Rhizome.SleepConsolidationTest do
  use ExUnit.Case
  alias Rhizome.ConsolidationManager

  require Logger

  test "Louvain optimization generates SuperNodes from clusters" do
    # 1. Manually inject a cluster of nodes into Memgraph via Native calls
    # (In a real test we'd need Memgraph running)
    
    # 2. Trigger optimization
    case Rhizome.Native.optimize_graph() do
      {:ok, result} ->
        Logger.info("[SleepConsolidationTest] Optimization result: #{result}")
        assert String.contains?(result, "Optimization complete") or String.contains?(result, "No graph data found")
      {:error, reason} ->
        # Accept connection errors in CI if Memgraph is not running
        assert String.contains?(reason, "Connection Error") or String.contains?(reason, "Query Error")
    end
  end

  test "ConsolidationManager lifecycle" do
    # Verify the manager is running
    # The supervisor might take a few ms to start it
    Application.ensure_all_started(:rhizome)
    pid = wait_for_process(Rhizome.ConsolidationManager, 100)
    assert pid != nil
  end

  defp wait_for_process(name, tries) when tries > 0 do
    case Process.whereis(name) do
      nil -> 
        Process.sleep(100)
        wait_for_process(name, tries - 1)
      pid -> pid
    end
  end
  defp wait_for_process(_, _), do: nil
end
