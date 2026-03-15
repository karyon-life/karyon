defmodule Core.ApoptosisChaosTest do
  use ExUnit.Case, async: false
  require Logger

  setup do
    # Application supervisor already starts this
    :ok
  end

  test "resilience under high cell churn" do
    # 1. Spawn a baseline cluster
    dna_path = Path.expand("../config/genetics/base_stem_cell.yml", __DIR__)
    
    cells = Enum.map(1..20, fn _ ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)

    # 2. Chaos Loop: Kill 10% of cells every 100ms for 1 second
    # Note: Since they are currently :temporary, they won't restart automatically!
    # We will verify that we can still spawn MORE cells and the supervisor doesn't crash.
    
    Enum.each(1..10, fn _ ->
      to_kill = Enum.take_random(cells, 2)
      Enum.each(to_kill, fn pid ->
        if Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end)
      Process.sleep(100)
    end)

    # 3. Verify survivors and spawn new ones
    survivors = Enum.filter(cells, &Process.alive?/1)
    Logger.info("[Chaos] Survivors: #{length(survivors)}/20")
    
    # Spawn replacements
    for _ <- 1..(20 - length(survivors)) do
      assert {:ok, _pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
    end

    # 4. Final check: supervisor is healthy
    assert Process.alive?(Process.whereis(Core.EpigeneticSupervisor))
  end
end
