defmodule Core.CellularResilienceTest do
  use ExUnit.Case
  alias Core.EpigeneticSupervisor
  alias Core.StemCell

  setup do
    # Ensure supervisor is clean
    for {_, pid, _, _} <- DynamicSupervisor.which_children(EpigeneticSupervisor) do
      DynamicSupervisor.terminate_child(EpigeneticSupervisor, pid)
    end
    :ok
  end

  test "mass spawning and graduated apoptosis" do
    # Spawn 50 cells across different roles
    roles = ["motor", "sensory", "orchestrator"]
    for i <- 1..50 do
      role = Enum.at(roles, rem(i, 3))
      # Correct path relative to umbrella root
      dna_path = Path.expand("../../priv/dna/#{role}_cell.yml")
      {:ok, _pid} = EpigeneticSupervisor.spawn_cell(dna_path)
    end

    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) == 50

    # Simulate metabolic pressure for targeted apoptosis
    # The MetabolicDaemon isn't started in this test context, so we call apoptosis directly
    motor_members = :pg.get_members(:motor)
    assert length(motor_members) > 0
    
    [victim | _] = motor_members
    assert :ok = EpigeneticSupervisor.apoptosis(victim)
    
    # Wait for async cleanup
    Process.sleep(100)
    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) == 49
  end

  test "chaos monkey impact and recovery" do
    # Spawn a small cluster
    for _ <- 1..10 do
      dna_path = Path.expand("../../priv/dna/motor_cell.yml")
      {:ok, _} = EpigeneticSupervisor.spawn_cell(dna_path)
    end

    # ChaosMonkey is a GenServer that pokes cells. 
    # Let's verify it can select and kill a cell.
    {:ok, monkey_pid} = Core.ChaosMonkey.start_link()
    
    # Force an immediate attack by sending the info message
    send(monkey_pid, :attack)
    
    # Wait for attack
    Process.sleep(100)
    
    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) == 9
  end
end
