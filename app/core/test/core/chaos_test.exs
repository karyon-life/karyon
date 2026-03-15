defmodule Core.ChaosTest do
  use ExUnit.Case
  require Logger

  @cell_count 1000 # Scaled down for CI/Local testing, production would use 500k

  setup_all do
    # Ensure dependencies are started
    Application.ensure_all_started(:core)
    Application.ensure_all_started(:nervous_system)
    :ok
  end

  test "Global Chaos: Resilience to Mass Apoptosis" do
    Logger.info("[ChaosTest] Spawning #{@cell_count} Stem Cells...")
    
    dna_path = "priv/dna/architect_planner.yml"
    
    cells = Enum.map(1..@cell_count, fn _ ->
      {:ok, pid} = Core.StemCell.start(dna_path)
      pid
    end)

    assert length(cells) == @cell_count
    
    # 1. Simulate Mass Apoptosis: Kill 20% of the cells
    apoptosis_count = round(@cell_count * 0.2)
    {to_kill, survivors} = Enum.split(Enum.shuffle(cells), apoptosis_count)
    
    Logger.warning("[ChaosTest] Executing Mass Apoptosis on #{apoptosis_count} cells.")
    
    Enum.each(to_kill, fn pid ->
      Process.exit(pid, :kill)
    end)

    # Allow supervisors to settle (though here we started them directly for simplicity)
    Process.sleep(500)

    # 2. Simulate Broadcast Storm: Trigger High Metabolic Stress
    Logger.warning("[ChaosTest] Triggering Global Metabolic Spike (High Severity).")
    
    # We use the MetabolicDaemon's internal broadcast logic or call it directly
    # Here we simulate the spike by calling the daemon's broadcast
    # or sending a manual spike via NATS if started.
    # For now, we simulate the effect on survivors by sending them the info message.
    
    Enum.each(survivors, fn pid ->
      send(pid, {:msg, "metabolic.spike", encode_spike("high")})
    end)

    # 3. Verify survivors enter Digital Torpor
    Process.sleep(500)
    
    torpor_count = Enum.count(survivors, fn pid ->
      if Process.alive?(pid) do
        GenServer.call(pid, :get_status) == :torpor
      else
        false
      end
    end)

    Logger.info("[ChaosTest] Survivors in Torpor: #{torpor_count}/#{length(survivors)}")
    
    # In a real biological system, some might undergo secondary apoptosis
    assert torpor_count > 0
    
    # Cleanup
    Enum.each(survivors, fn pid ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)
  end

  defp encode_spike(severity) do
    msg = %Karyon.NervousSystem.MetabolicSpike{
      metric_type: "chaos_injection",
      value: 99.0,
      threshold: 10.0,
      timestamp: System.system_time(:second),
      severity: severity
    }
    {:ok, binary} = Karyon.NervousSystem.MetabolicSpike.encode(msg)
    binary
  end
end
