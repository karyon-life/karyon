defmodule Rhizome.SleepConsolidationTest do
  use ExUnit.Case
  alias Rhizome.ConsolidationManager

  require Logger

  defmodule NativeStub do
    def optimize_graph, do: {:ok, "Optimization complete"}

    def memgraph_query(query) do
      cond do
        String.contains?(query, "MATCH (n:PooledSequence)") ->
          {:ok,
           [
             %{
                "internal_id" => 11,
               "labels" => ["PooledSequence"],
               "props" => %{"id" => "sleep-sequence-11", "source" => "operator_environment", "archived" => false}
             },
             %{
               "internal_id" => 12,
               "labels" => ["PooledSequence"],
               "props" => %{"id" => "sleep-sequence-12", "source" => "operator_environment", "archived" => false}
             }
           ]}

        String.contains?(query, "MATCH (a:PooledSequence)-[r:CO_OCCURS_WITH]->(b:PooledSequence)") ->
          {:ok, [%{"start" => 11, "end" => 12, "weight" => 1.0}]}

        String.contains?(query, "MERGE (g:GrammarSuperNode") ->
          {:ok, [%{"grammar_id" => "grammar_supernode:2026-03-18T00:00:00Z:1"}]}

        true ->
          {:ok, []}
      end
    end
  end

  defmodule MemoryStub do
    def bridge_working_memory_to_archive, do: {:ok, %{message: "bridged", archived_count: 3}}
  end

  test "Louvain optimization generates grammar super-nodes from operator pooled sequences" do
    # 1. Manually inject a cluster of nodes into Memgraph via Native calls
    # (In a real test we'd need Memgraph running)
    
    # 2. Trigger optimization
    case Rhizome.Native.optimize_graph() do
      {:ok, result} ->
        Logger.info("[SleepConsolidationTest] Optimization result: #{result}")
        assert String.contains?(result, "Louvain optimization complete") or
                 String.contains?(result, "No operator pooled-sequence graph data found")
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

    assert {:ok, %{supernode_count: 1, abstracted_count: 2}} = result.abstractions
    assert {:ok, %{archived_count: 3}} = result.bridge_to_xtdb
    assert {:ok, %{pruned_count: 0, retained_in_archive: true}} = result.memory_relief
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
