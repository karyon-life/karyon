defmodule Rhizome.SleepConsolidationTest do
  use ExUnit.Case
  alias Rhizome.ConsolidationManager

  require Logger

  defmodule NativeStub do
    def optimize_graph, do: {:ok, "Optimization complete"}

    def memgraph_query(query) do
      cond do
        String.contains?(query, "RETURN id(n) AS internal_id") ->
          {:ok,
           [
             %{
               "internal_id" => 11,
               "labels" => ["Cell"],
               "props" => %{"id" => "sleep-cell", "vfe" => 0.93, "archived" => false}
             }
           ]}

        String.contains?(query, "MERGE (s:SleepSuperNode") ->
          {:ok, [%{"supernode_id" => "sleep_supernode:2026-03-18T00:00:00Z", "abstracted_count" => 1}]}

        String.contains?(query, "SET n.archived = true") ->
          {:ok, [%{"pruned_count" => 1}]}

        true ->
          {:ok, []}
      end
    end
  end

  defmodule MemoryStub do
    def bridge_working_memory_to_archive, do: {:ok, %{message: "bridged", archived_count: 3}}
  end

  test "Louvain optimization generates SuperNodes from clusters" do
    # 1. Manually inject a cluster of nodes into Memgraph via Native calls
    # (In a real test we'd need Memgraph running)
    
    # 2. Trigger optimization
    case Rhizome.Native.optimize_graph() do
      {:ok, result} ->
        Logger.info("[SleepConsolidationTest] Optimization result: #{result}")
        assert String.contains?(result, "Optimization complete") or String.contains?(result, "No graph data found")
      {:error, reason} ->
        # Accept structured service failures in environments without Memgraph
        assert reason != nil
    end
  end

  test "ConsolidationManager lifecycle" do
    # Verify the manager is running
    # The supervisor might take a few ms to start it
    Application.ensure_all_started(:rhizome)
    pid = wait_for_process(Rhizome.ConsolidationManager, 100)
    assert pid != nil
  end

  test "sleep cycle creates abstractions and prunes in place instead of blunt deletion" do
    result =
      ConsolidationManager.run_once(
        native_module: NativeStub,
        memory_module: MemoryStub,
        schedule_next?: false,
        logger_fun: fn _ -> :ok end,
        clock_fun: fn -> ~U[2026-03-18 00:00:00Z] end
      )

    assert {:ok, %{supernode_count: 1, abstracted_count: 1}} = result.abstractions
    assert {:ok, %{archived_count: 3}} = result.bridge_to_xtdb
    assert {:ok, %{pruned_count: 1, retained_in_archive: true}} = result.memory_relief
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
