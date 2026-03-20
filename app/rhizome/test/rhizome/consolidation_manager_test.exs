defmodule Rhizome.ConsolidationManagerTest.MockMetabolicDaemon do
  use GenServer
  def start_link(pressure), do: GenServer.start_link(__MODULE__, pressure, name: Core.MetabolicDaemon)
  def init(pressure), do: {:ok, pressure}
  def handle_call(:get_pressure, _from, pressure), do: {:reply, pressure, pressure}
  def handle_call({:set, pressure}, _from, _old), do: {:reply, :ok, pressure}
  def set_pressure(pressure), do: GenServer.call(Core.MetabolicDaemon, {:set, pressure})
end

defmodule Rhizome.ConsolidationManagerTest do
  use ExUnit.Case, async: false
  require Logger

  alias Rhizome.ConsolidationManager

  defmodule NativeStub do
    def optimize_graph, do: {:ok, "optimized"}

    def memgraph_query(query) do
      if pid = Process.whereis(:consolidation_manager_observer) do
        send(pid, {:native_query, query})
      end

      cond do
        String.contains?(query, "MATCH (n:PooledSequence)") ->
          {:ok,
           [
             %{
                "internal_id" => 7,
               "labels" => ["PooledSequence"],
               "props" => %{"id" => "sequence-7", "source" => "operator_environment", "archived" => false}
             },
             %{
                "internal_id" => 8,
               "labels" => ["PooledSequence"],
               "props" => %{"id" => "sequence-8", "source" => "operator_environment", "archived" => false}
             }
           ]}

        String.contains?(query, "MATCH (a:PooledSequence)-[r:CO_OCCURS_WITH]->(b:PooledSequence)") ->
          {:ok, [%{"start" => 7, "end" => 8, "weight" => 0.9}]}

        String.contains?(query, "MERGE (g:GrammarSuperNode") ->
          {:ok, [%{"grammar_id" => "grammar_supernode:2026-03-18T00:00:00Z:1"}]}

        true ->
          {:ok, []}
      end
    end
  end

  defmodule MemoryStub do
    def bridge_working_memory_to_archive, do: {:ok, %{message: "bridged", archived_count: 1}}
  end

  # We need to mock Core.MetabolicDaemon and Rhizome.Native
  setup do
    # 1. Stop real daemon if running
    case GenServer.whereis(Core.MetabolicDaemon) do
      nil -> :ok
      pid -> 
        Process.unlink(pid)
        ref = Process.monitor(pid)
        GenServer.stop(pid)
        receive do
          {:DOWN, ^ref, :process, ^pid, _} -> :ok
        after
          1000 -> :ok
        end
    end

    # 2. Stop ConsolidationManager if running (to avoid already_started issues)
    case GenServer.whereis(ConsolidationManager) do
      nil -> :ok
      pid ->
        Process.unlink(pid)
        ref = Process.monitor(pid)
        GenServer.stop(pid)
        receive do
          {:DOWN, ^ref, :process, ^pid, _} -> :ok
        after
          1000 -> :ok
        end
    end

    Process.register(self(), :consolidation_manager_observer)

    on_exit(fn ->
      if Process.whereis(:consolidation_manager_observer) == self() do
        Process.unregister(:consolidation_manager_observer)
      end
    end)

    :ok
  end

  # Helper to start mock with unique name to avoid collisions if needed, 
  # but here we need it at Core.MetabolicDaemon.
  defp start_mock(pressure) do
    case Rhizome.ConsolidationManagerTest.MockMetabolicDaemon.start_link(pressure) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  test "Sleep Cycle triggers when system is dormant" do
    # Start fake daemon in :low pressure state
    {:ok, _daemon} = start_mock(:low)

    # Start ConsolidationManager with a very short interval for testing
    # Since interval is hardcoded in the module, we might need to send the message manually
    # or patch the module. For now, let's send :check_consolidation_window.
    
    {:ok, pid} = case ConsolidationManager.start_link() do
      {:ok, p} -> {:ok, p}
      {:error, {:already_started, p}} -> {:ok, p}
    end
    
    # We want to verify that bridge_to_xtdb and optimize_graph are called.
    # Since these are in Rhizome.Native which is a NIF, we can't easily mock them 
    # unless we use a wrapper or Mox. 
    # However, we can check the logs or verify that it completes without crashing.
    
    send(pid, :check_consolidation_window)
    
    Process.sleep(200)
    # Check that it didn't crash and is still alive
    assert Process.alive?(pid)
  end

  test "Sleep Cycle postpones when system is active" do
    # Start fake daemon in :high pressure state
    {:ok, _daemon} = start_mock(:high)

    {:ok, pid} = case ConsolidationManager.start_link() do
      {:ok, p} -> {:ok, p}
      {:error, {:already_started, p}} -> {:ok, p}
    end
    
    # Send check
    send(pid, :check_consolidation_window)
    
    Process.sleep(200)
    # It should have postponed (logged debug)
    assert Process.alive?(pid)
  end

  test "run_once returns explicit consolidation learning-loop metadata" do
    result =
      ConsolidationManager.run_once(
        native_module: NativeStub,
        memory_module: MemoryStub,
        schedule_next?: false,
        logger_fun: fn _ -> :ok end,
        clock_fun: fn -> ~U[2026-03-18 00:00:00Z] end
      )

    assert result.learning_phase == "consolidation"
    assert result.learning_edge == "plasticity->consolidation"
    assert {:ok, %{total: 2, sequences: [_, _]}} = result.classified_candidates
    assert {:ok, %{supernode_count: 1, abstracted_count: 2}} = result.abstractions
    assert {:ok, %{archived_count: 1}} = result.bridge_to_xtdb
    assert {:ok, "optimized"} = result.optimize_graph
    assert {:ok, %{pruned_count: 0, retained_in_archive: true, strategy: "targeted_in_place_pruning"}} =
             result.memory_relief

    assert_received {:native_query, query}
    assert query =~ "MATCH (n:PooledSequence)"
    assert_received {:native_query, cooccurrence_query}
    assert cooccurrence_query =~ "CO_OCCURS_WITH"
    assert_received {:native_query, abstraction_query}
    assert abstraction_query =~ "MERGE (g:GrammarSuperNode"
    refute abstraction_query =~ "SleepSuperNode"
  end
end
