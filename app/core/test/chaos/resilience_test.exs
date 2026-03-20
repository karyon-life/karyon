defmodule Core.ChaosResilienceTest do
  use ExUnit.Case
  alias Core.{EpigeneticSupervisor, ChaosMonkey}

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(opts \\ []) do
      pressure = Keyword.get(opts, :pressure, :low)
      GenServer.start_link(__MODULE__, pressure, name: Core.MetabolicDaemon)
    end

    def init(pressure), do: {:ok, pressure}
    def handle_call(:get_pressure, _from, pressure), do: {:reply, pressure, pressure}
    def handle_call(:get_policy, _from, pressure), do: {:reply, Core.MetabolismPolicy.build_policy(pressure), pressure}
    def handle_call(:get_runtime_status, _from, pressure) do
      {:reply,
       %{
         pressure: pressure,
         consciousness_state: :awake,
         membrane_open: true,
         motor_output_open: true,
         preflight_status: :ok,
         calibrated: true,
         strict_preflight: false
       }, pressure}
    end
  end

  setup do
    # Ensure supervisor is started and ready
    case TestUtils.wait_for_process(Core.EpigeneticSupervisor) do
      :ok -> :ok
      _ -> 
        Application.ensure_all_started(:core)
        TestUtils.wait_for_process(Core.EpigeneticSupervisor)
    end

    if Process.whereis(Core.Supervisor) do
      Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
      Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end

    {:ok, fake_daemon} = FakeMetabolicDaemon.start_link()

    on_exit(fn ->
      if Process.alive?(fake_daemon), do: GenServer.stop(fake_daemon)

      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, {Core.MetabolicDaemon, []})
      end
    end)

    :ok
  end

  test "platform survives 20% cellular churn during high synaptic load" do
    dna_path = "/tmp/chaos_resilience_stem_#{System.unique_integer([:positive])}.yml"

    File.write!(dna_path, """
    cell_type: tabula_rasa_stem
    subscriptions:
      - metabolic.spike
    synapses: []
    allowed_actions: []
    """)

    on_exit(fn -> File.rm(dna_path) end)

    pids = for _ <- 1..6 do
      {:ok, pid} = EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end
    
    # 2. Start Chaos Monkey to sporadically kill them
    {:ok, monkey_pid} = ChaosMonkey.start_link(probability: 0.2, interval: 100, max_victims: 1)
    
    # 3. Let it run for a few seconds
    Process.sleep(2000)
    
    # 4. Verify system is still responsive
    assert Process.alive?(monkey_pid)
    assert EpigeneticSupervisor.active_cell_count() > 0
    assert {:ok, discovered_pid} = EpigeneticSupervisor.discover_cell(:tabula_rasa_stem)
    assert Process.alive?(discovered_pid)
    
    # Cleanup
    GenServer.stop(monkey_pid)

    for pid <- pids do
      if Process.alive?(pid) do
        Process.exit(pid, :kill)
      end
    end
  end
end
