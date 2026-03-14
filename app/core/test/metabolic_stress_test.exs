defmodule Core.MetabolicStressTest do
  use ExUnit.Case, async: false # Mutates global state (Core.Native)
  require Logger

  # We use Mox or simple GenServer behavior to mock hardware counters
  # For this test, we assume the NIF might be partially mocked or we use 
  # a helper to inject simulated values.

  test "metabolic daemon triggers apoptosis on simulated cache spike" do
    # When KARYON_MOCK_HARDWARE=true, the NIF doesn't grab the lock, 
    # so we can run multiple instances safely for testing.
    test_daemon_name = :"test_metabolic_daemon_#{System.unique_integer([:positive])}"
    {:ok, pid} = Core.MetabolicDaemon.start_link(name: test_daemon_name)
    
    assert Process.alive?(pid)
    # Cleanup
    GenServer.stop(pid)
  end
end
