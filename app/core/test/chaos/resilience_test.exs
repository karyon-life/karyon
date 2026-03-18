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
    # 1. Spawn a swarm of cells
    pids = for _ <- 1..50 do
      {:ok, pid} = EpigeneticSupervisor.spawn_cell()
      pid
    end
    
    # 2. Start Chaos Monkey to sporadically kill them
    {:ok, monkey_pid} = ChaosMonkey.start_link(probability: 0.2, interval: 100, max_victims: 3)
    
    # 3. Let it run for a few seconds
    Process.sleep(2000)
    
    # 4. Verify system is still responsive
    assert Process.alive?(monkey_pid)
    assert EpigeneticSupervisor.active_cell_count() > 0
    assert {:ok, discovered_pid} = EpigeneticSupervisor.discover_cell(:stem_cell)
    assert Process.alive?(discovered_pid)
    
    # Cleanup
    GenServer.stop(monkey_pid)
    for pid <- pids, do: if(Process.alive?(pid), do: EpigeneticSupervisor.apoptosis(pid))
  end
end
