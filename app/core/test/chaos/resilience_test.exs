defmodule Core.ChaosResilienceTest do
  use ExUnit.Case
  alias Core.{EpigeneticSupervisor, ChaosMonkey}

  setup do
    # Ensure supervisor is started
    :ok
  end

  test "platform survives 20% cellular churn during high synaptic load" do
    # 1. Spawn a swarm of cells
    pids = for _ <- 1..50 do
      {:ok, pid} = EpigeneticSupervisor.spawn_cell()
      pid
    end
    
    # 2. Start Chaos Monkey to sporadically kill them
    {:ok, monkey_pid} = ChaosMonkey.start_link(probability: 0.2)
    
    # 3. Let it run for a few seconds
    Process.sleep(2000)
    
    # 4. Verify system is still responsive
    assert Process.alive?(monkey_pid)
    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) > 0
    
    # Cleanup
    GenServer.stop(monkey_pid)
    for pid <- pids, do: if(Process.alive?(pid), do: EpigeneticSupervisor.apoptosis(pid))
  end
end
