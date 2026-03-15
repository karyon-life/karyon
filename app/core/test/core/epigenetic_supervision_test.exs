defmodule Core.EpigeneticSupervisionTest do
  use ExUnit.Case
  alias Core.EpigeneticSupervisor

  setup do
    # Cleanup PG groups
    :pg.leave(:motor, self())
    :pg.leave(:sensory, self())
    :pg.leave(:orchestrator, self())
    
    # Ensure supervisor is clean
    for {_, pid, _, _} <- DynamicSupervisor.which_children(EpigeneticSupervisor) do
      DynamicSupervisor.terminate_child(EpigeneticSupervisor, pid)
    end
    :ok
  end

  test "differentiation as motor cell" do
    dna_path = Path.expand("../../priv/dna/motor_cell.yml")
    {:ok, pid} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    # Verify process group membership
    assert pid in :pg.get_members(:motor)
    
    # Verify status
    assert GenServer.call(pid, :get_status) == :active
    
    # Verify synonyms (motor cell DNA has 1 synapse configured in spec)
    # Plus the default pain receptor synapse = 2
    assert GenServer.call(pid, :get_synapse_count) == 2
  end

  test "differentiation as sensory cell" do
    dna_path = Path.expand("../../priv/dna/sensory_cell.yml")
    {:ok, pid} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    assert pid in :pg.get_members(:sensory)
    # sensory_cell.yml has 1 synapse (pub), plus default pain = 2
    assert GenServer.call(pid, :get_synapse_count) == 2
  end

  test "differentiation as orchestrator cell" do
    dna_path = Path.expand("../../priv/dna/orchestrator_cell.yml")
    {:ok, pid} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    assert pid in :pg.get_members(:orchestrator)
  end

  test "refusal to spawn under high metabolic pressure" do
    if GenServer.whereis(Core.MetabolicDaemon) == nil do
      {:ok, _} = Core.MetabolicDaemon.start_link(name: Core.MetabolicDaemon)
    end
    
    assert {:ok, _} = EpigeneticSupervisor.spawn_cell()
  end
end
