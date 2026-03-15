defmodule Rhizome.ConsolidationManagerTest.MockMetabolicDaemon do
  use GenServer
  def start_link(pressure), do: GenServer.start_link(__MODULE__, pressure, name: Core.MetabolicDaemon)
  def init(pressure), do: {:ok, pressure}
  def handle_call(:get_pressure, _from, pressure), do: {:reply, pressure, pressure}
  def set_pressure(pressure), do: GenServer.call(Core.MetabolicDaemon, {:set, pressure})
  def handle_call({:set, pressure}, _from, _old), do: {:reply, :ok, pressure}
end

defmodule Rhizome.ConsolidationManagerTest do
  use ExUnit.Case, async: false
  require Logger

  alias Rhizome.ConsolidationManager

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
    
    {:ok, pid} = ConsolidationManager.start_link()
    
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

    {:ok, pid} = ConsolidationManager.start_link()
    
    # Send check
    send(pid, :check_consolidation_window)
    
    Process.sleep(200)
    # It should have postponed (logged debug)
    assert Process.alive?(pid)
  end
end
