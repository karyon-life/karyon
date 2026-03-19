defmodule Core.EpigeneticSupervisorStressTest do
  use ExUnit.Case, async: false # Async: false because we are stressing the system
  alias Core.EpigeneticSupervisor

  defmodule MemoryStub do
    def load_cell_state(_lineage_id), do: {:error, :not_found}
    def checkpoint_cell_state(snapshot), do: {:ok, %{id: snapshot["lineage_id"] || "checkpoint"}}
    def submit_prediction_error(_event), do: {:ok, %{id: "prediction_error"}}
    def submit_execution_outcome(_event), do: {:ok, %{id: "execution_outcome"}}
    def submit_execution_telemetry(_event), do: {:ok, %{id: "execution_telemetry"}}

    def submit_differentiation_event(event) do
      if pid = Process.whereis(:epigenetic_supervisor_stress_observer) do
        send(pid, {:differentiation_event_persisted, event})
      end

      {:ok, %{id: event["lineage_id"]}}
    end
  end

  @dna_path Path.expand("../../../../priv/dna/motor_cell.yml", __DIR__)

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(_opts), do: GenServer.start_link(__MODULE__, %{pressure: :low}, name: Core.MetabolicDaemon)
    def init(state), do: {:ok, state}
    def handle_call(:get_pressure, _from, state), do: {:reply, state.pressure, state}
    def handle_call(:get_policy, _from, state), do: {:reply, Core.MetabolismPolicy.build_policy(state.pressure), state}
    def handle_cast({:set_pressure, pressure}, state), do: {:noreply, %{state | pressure: pressure}}
  end

  setup do
    # Ensure core is started
    Application.ensure_all_started(:core)
    original_module = Application.get_env(:core, :memory_module)
    Application.put_env(:core, :memory_module, MemoryStub)
    Process.register(self(), :epigenetic_supervisor_stress_observer)
    
    # Wait for the supervisor to be registered and ready
    case wait_for_ready(Core.EpigeneticSupervisor, 50) do
      :ok -> :ok
      _ -> 
        require Logger
        Logger.error("[StressTest] EpigeneticSupervisor failed to start!")
    end

    if pid = Process.whereis(EpigeneticSupervisor) do
      for {_, child_pid, _, _} <- DynamicSupervisor.which_children(pid) do
        DynamicSupervisor.terminate_child(pid, child_pid)
      end
    end

    # Start a fake MetabolicDaemon for these tests to ensure deterministic pressure
    if Process.whereis(Core.Supervisor) do
      Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
      Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end
    
    on_exit(fn ->
      if Process.whereis(:epigenetic_supervisor_stress_observer) == self(), do: Process.unregister(:epigenetic_supervisor_stress_observer)

      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end

      if Process.whereis(Core.Supervisor) do
        child_spec = {Core.MetabolicDaemon, []}
        Supervisor.start_child(Core.Supervisor, child_spec)
      end
    end)
    
    # Wait a bit for transition
    Process.sleep(100)
    
    {:ok, fake_daemon} = FakeMetabolicDaemon.start_link([])
    on_exit(fn -> 
      safe_stop(fake_daemon)
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

    assert_receive {:differentiation_event_persisted, event}
    assert event["role"] == "motor"
    assert event["pressure"] == "low"

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

  test "medium pressure still transcribes lower-cost non-speculative variants", %{daemon: daemon} do
    speculative_path = Path.expand("../../../../priv/dna/speculative_cell.yml", __DIR__)
    motor_path = Path.expand("../../../../priv/dna/motor_cell.yml", __DIR__)

    GenServer.cast(daemon, {:set_pressure, :medium})

    {:ok, pid} =
      EpigeneticSupervisor.spawn_cell(
        speculative_path,
        variants: [speculative_path, motor_path]
      )

    assert Process.alive?(pid)
    assert pid in :pg.get_members(:motor)
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

  defp safe_stop(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :ok
      end
    else
      :ok
    end
  end
end
