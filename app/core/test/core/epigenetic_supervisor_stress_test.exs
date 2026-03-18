defmodule Core.EpigeneticSupervisorStressTest do
  use ExUnit.Case, async: false # Async: false because we are stressing the system
  alias Core.EpigeneticSupervisor

  @dna_path Path.expand("../../../../priv/dna/motor_cell.yml", __DIR__)

  setup do
    # Ensure core is started
    Application.ensure_all_started(:core)
    
    # Wait for the supervisor to be registered and ready
    case wait_for_ready(Core.EpigeneticSupervisor, 50) do
      :ok -> :ok
      _ -> 
        require Logger
        Logger.error("[StressTest] EpigeneticSupervisor failed to start!")
    end

    # Start a fake MetabolicDaemon for these tests to ensure deterministic pressure
    if Process.whereis(Core.Supervisor) do
      Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
      Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end
    
    on_exit(fn ->
      if Process.whereis(Core.Supervisor) do
        child_spec = {Core.MetabolicDaemon, []}
        Supervisor.start_child(Core.Supervisor, child_spec)
      end
    end)
    
    # Wait a bit for transition
    Process.sleep(100)
    
    defmodule FakeMetabolicDaemon do
      use GenServer
      def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: Core.MetabolicDaemon)
      def init(_), do: {:ok, %{pressure: :low}}
      def handle_call(:get_pressure, _from, state), do: {:reply, state.pressure, state}
      def handle_cast({:set_pressure, p}, state), do: {:noreply, %{state | pressure: p}}
    end

    {:ok, fake_daemon} = FakeMetabolicDaemon.start_link([])
    on_exit(fn -> 
      if Process.alive?(fake_daemon), do: GenServer.stop(fake_daemon)
    end)
    
    {:ok, daemon: fake_daemon}
  end

  test "mass spawning and apoptosis resilience", %{daemon: _daemon} do
    # 1. Spawn 100 cells rapidly
    pids = for _ <- 1..100 do
      {:ok, pid} = EpigeneticSupervisor.spawn_cell(@dna_path)
      pid
    end

    assert length(pids) == 100
    
    # Verify all are alive
    Enum.each(pids, fn pid -> assert Process.alive?(pid) end)
    assert Enum.sort(EpigeneticSupervisor.members_for_role(:motor)) == Enum.sort(pids)

    Enum.each(1..20, fn _ ->
      assert {:ok, discovered_pid} = EpigeneticSupervisor.discover_cell(:motor)
      assert discovered_pid in pids
    end)

    # 2. Kill them all rapidly
    Enum.each(pids, fn pid -> EpigeneticSupervisor.apoptosis(pid) end)

    # Allow a moment for cleanup
    Process.sleep(200)

    # Verify all are dead
    Enum.each(pids, fn pid -> refute Process.alive?(pid) end)
    assert EpigeneticSupervisor.members_for_role(:motor) == []
    assert {:error, :no_gradient_detected} = EpigeneticSupervisor.discover_cell(:motor)
  end

  test "metabolic starvation refusal", %{daemon: daemon} do
    # Set pressure to high
    GenServer.cast(daemon, {:set_pressure, :high})
    
    # Attempt to spawn
    assert {:error, :metabolic_starvation} = EpigeneticSupervisor.spawn_cell(@dna_path)
  end

  defp wait_for_ready(name, attempts) do
    if Process.whereis(name) do
      :ok
    else
      if attempts > 0 do
        Process.sleep(100)
        wait_for_ready(name, attempts - 1)
      else
        {:error, :timeout}
      end
    end
  end
end
