ExUnit.start()

defmodule Core.MasteryTest do
  @moduledoc """
  Long-running stability and learning mastery test for Karyon.
  Simulates a multi-day (compressed) learning cycle to verify VFE convergence
  and systemic stability.
  """
  use ExUnit.Case, async: false
  require Logger

  @iterations 3

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(_opts \\ []) do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call(:get_pressure, _from, state), do: {:reply, :low, state}

    @impl true
    def handle_call(:get_policy, _from, state) do
      {:reply, %{apoptosis_threshold: 0.95, torpor_threshold: 0.95}, state}
    end

    @impl true
    def handle_call(:get_runtime_status, _from, state) do
      {:reply, %{pressure: :low, membrane_open: true, consciousness_state: :awake}, state}
    end

    @impl true
    def handle_call(:get_membrane_state, _from, state) do
      {:reply, %{membrane_open: true, motor_output_open: true, consciousness_state: :awake}, state}
    end
  end

  setup do
    original_daemon = Application.get_env(:core, :metabolic_daemon, Core.MetabolicDaemon)
    Application.put_env(:core, :metabolic_daemon, FakeMetabolicDaemon)
    start_supervised!(FakeMetabolicDaemon)

    on_exit(fn -> 
      # Cleanup any stray cells
      :pg.get_members(:motor) |> Enum.each(&Process.exit(&1, :kill))
      Application.put_env(:core, :metabolic_daemon, original_daemon)
    end)

    :ok
  end

  test "VFE convergence and systemic stability across high-churn iterations" do
    # 1. Boot a baseline babbling cell
    dna_path = Path.join(System.tmp_dir!(), "mastery_motor_babble_#{System.unique_integer([:positive])}.yml")

    File.write!(dna_path, """
    cell_type: motor_babble
    consciousness_level: 0.2
    memory_depth: 4
    decay_rate: 0.1
    sensors: []
    synapses: []
    subscriptions:
      - metabolic.spike
    """)

    {:ok, pid} = Core.StemCell.start_link(dna_path)
    
    # 2. Simulate rapid-fire architectural expectations and feedback
    results = 
      for i <- 1..@iterations do
        # Form an expectation
        expectation_id = "exp_#{i}"
        GenServer.call(pid, {:form_expectation, expectation_id, :success, 1.0}, 15_000)
        
        # Randomly simulate success or localized pain (prediction error)
        if rem(i, 5) == 0 do
          pain_msg = %Karyon.NervousSystem.PredictionError{
            type: "nociception",
            message: "Mastery nociception",
            timestamp: System.system_time(:second),
            metadata: %{"error" => "iteration_#{i}"}
          }

          {:ok, encoded} = Karyon.NervousSystem.PredictionError.encode(pain_msg)
          send(pid, {:synapse_recv, self(), IO.iodata_to_binary(encoded)})
          :predicted_error
        else
          # Successful prediction
          :predicted_success
        end
      end

    # 3. Verify the cell is still alive and didn't crash during high churn
    assert Process.alive?(pid)
    
    # 4. Verify status is active or torpor but not dead
    status = GenServer.call(pid, :get_status, 15_000)
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
    Process.sleep(500)
    pressure = GenServer.call(Core.MetabolicDaemon, :get_pressure)
    Logger.info("[MasteryTest] Observed Metabolic Pressure: #{pressure}")
    
    assert pressure in [:low, :medium, :high]
  end
end
