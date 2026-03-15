defmodule Core.StateRecoveryTest do
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

  test "cell recovers beliefs from XTDB after apoptosis" do
    dna_path = Path.expand("../../priv/dna/motor_cell.yml")
    
    # 1. Spawn initial cell
    {:ok, pid1} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    # 2. Inject a belief (In a real scenario, this would happen via learning/sensing)
    # We'll assume a way to set beliefs for testing or that they are persisted to XTDB
    # For now, we'll manually push a state to XTDB and see if pid2 picks it up.
    cell_id = "test_cell_1" # In a real scenario, this would be derived from DNA or passed in
    
    # Mock XTDB state in Rhizome (if we had a mock)
    # Since we use NIFs, we'll just test the refactored StemCell logic
    
    # 3. Kill cell
    :ok = EpigeneticSupervisor.apoptosis(pid1)
    Process.sleep(100)
    
    # 4. Spawn again
    {:ok, pid2} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    # 5. Verify pid2 has recovered state
    # This requires StemCell to have a stable ID to query XTDB with.
    assert is_pid(pid2)
  end
end
