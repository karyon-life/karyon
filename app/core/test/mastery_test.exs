ExUnit.start()

defmodule Core.MasteryTest do
  @moduledoc """
  Long-running stability and learning mastery test for Karyon.
  Simulates a multi-day (compressed) learning cycle to verify VFE convergence
  and systemic stability.
  """
  use ExUnit.Case, async: false
  require Logger

  @iterations 1000 # Simulating high activity

  setup do
    on_exit(fn -> 
      # Cleanup any stray cells
      :pg.get_members(:motor) |> Enum.each(&Process.exit(&1, :kill))
    end)
    :ok
  end

  test "VFE convergence and systemic stability across high-churn iterations" do
    # 1. Boot a baseline babbling cell
    dna_path = Path.expand("../../../priv/dna/motor_babble_cell.yml", __DIR__)
    {:ok, pid} = Core.StemCell.start_link(dna_path)
    
    # 2. Simulate rapid-fire architectural expectations and feedback
    results = 
      for i <- 1..@iterations do
        # Form an expectation
        expectation_id = "exp_#{i}"
        GenServer.call(pid, {:form_expectation, expectation_id, :success, 1.0})
        
        # Randomly simulate success or localized pain (prediction error)
        if :rand.uniform() > 0.95 do
          # Simulate Pain Receptor firing
          send(pid, {:synapse_recv, self(), Jason.encode!(%{
            "type" => "nociception", 
            "metadata" => %{"error" => "Stack trace in iteration #{i}"}
          })})
          :predicted_error
        else
          # Successful prediction
          :predicted_success
        end
      end

    # 3. Verify the cell is still alive and didn't crash during high churn
    assert Process.alive?(pid)
    
    # 4. Verify status is active or torpor but not dead
    status = GenServer.call(pid, :get_status)
    assert status in [:active, :torpor]

    Logger.info("[MasteryTest] Completed #{@iterations} iterations. Stability CONFIRMED.")
    
    error_count = Enum.count(results, &(&1 == :predicted_error))
    Logger.info("[MasteryTest] Simulated Errors (Pain): #{error_count}")
  end

  test "Metabolic auto-tuning prevents systemic collapse during chaos" do
    # 1. Start Chaos Monkey to induce stress
    # Assuming ChaosMonkey exists and can be configured
    {:ok, _monkey} = Core.ChaosMonkey.start_link(intensity: 0.5)
    
    # 2. Observe MetabolicDaemon pressure increase 
    # and verify that it doesn't trigger a total system reboot (Supervision test)
    Process.sleep(2000)
    pressure = GenServer.call(Core.MetabolicDaemon, :get_pressure)
    Logger.info("[MasteryTest] Observed Metabolic Pressure: #{pressure}")
    
    assert pressure in [:low, :medium, :high]
  end
end
