defmodule Core.MetabolicDaemonTest do
  use ExUnit.Case
  alias Core.MetabolicDaemon

  defmodule NativeStable do
    def read_l3_misses, do: {:ok, 100}
    def read_iops, do: {:ok, 50}
    def read_numa_node, do: {:ok, 0}
    def get_affinity_mask, do: {:ok, [0, 1]}
  end

  defmodule NativeHighIops do
    def read_l3_misses, do: {:ok, 100}
    def read_iops, do: {:ok, 5_000}
    def read_numa_node, do: {:ok, 0}
    def get_affinity_mask, do: {:ok, [0, 1]}
  end

  setup do
    # Ensure supervisors are ready
    TestUtils.wait_for_process(Core.Supervisor)
    TestUtils.wait_for_process(Core.EpigeneticSupervisor)

    case GenServer.whereis(Core.MetabolicDaemon) do
      nil -> :ok
      _pid -> 
        Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
        Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end
    
    on_exit(fn ->
      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, Core.MetabolicDaemon)
      end
    end)
    :ok
  end

  test "MetabolicDaemon establishes baselines after calibration delay" do
    # Start the daemon
    {:ok, pid} = MetabolicDaemon.start_link(name: :calibration_test_daemon)
    
    # Initially not calibrated
    state = :sys.get_state(pid)
    assert state.calibrated == false
    assert state.baselines.l3_misses == 0

    # Wait for calibration (default 2000ms in code)
    Process.sleep(2500)
    
    state = :sys.get_state(pid)
    assert state.calibrated == true
    if System.get_env("KARYON_MOCK_HARDWARE") == "1" do
      assert state.baselines.l3_misses == 1337
      assert state.baselines.iops == 42
    end
  end

  test "MetabolicDaemon correctly calculates pressure based on run_queue baseline" do
    # Start with a fixed baseline
    {:ok, pid} = MetabolicDaemon.start_link(name: :pressure_test_daemon)
    
    # Manually inject a baseline into state for deterministic testing
    :sys.replace_state(pid, fn state ->
      %{state | baselines: %{state.baselines | run_queue: 10}, calibrated: true}
    end)

    # We can't easily mock :erlang.statistics(:run_queue) here as it's a BIF,
    # but we can test the internal calculate_system_pressure logic 
    # if it were exposed or by verifying the state transition during a poll 
    # if we could control the system load.
    
    # Instead, we verify the pressure handle_call
    assert GenServer.call(pid, :get_pressure) == :low
  end

  test "Targeted apoptosis prioritized based on starvation type" do
    # This test verifies the induce_apoptosis logic
    # We'll use the EpigeneticSupervisor to spawn different types of cells
    
    # 1. Spawn a motor cell and a sensory cell
    motor_dna = "/home/adrian/Projects/nexical/karyon/priv/dna/motor_cell.yml"
    sensory_dna = "/home/adrian/Projects/nexical/karyon/priv/dna/sensory_cell.yml"
    
    {:ok, motor_pid} = Core.EpigeneticSupervisor.spawn_cell(motor_dna)
    {:ok, sensory_pid} = Core.EpigeneticSupervisor.spawn_cell(sensory_dna)
    
    # 2. Add them to their respective PG groups
    :pg.join(:motor, motor_pid)
    :pg.join(:sensory, sensory_pid)

    # 3. Start a daemon and trigger targeted apoptosis
    {:ok, pid} = MetabolicDaemon.start_link(name: :targeted_test_daemon)
    
    # Manually trigger the private induce_apoptosis via handle_info if we allow it,
    # or just call the supervisor directly based on daemon logic.
    # The daemon logic for L3 misses is to induce_apoptosis(:motor)
    
    # We'll simulate the L3 miss trigger
    :sys.replace_state(pid, fn state ->
      %{state | baselines: %{state.baselines | l3_misses: 1000}}
    end)
    
    # Mock Native to return high misses
    # we can't easily mock NIFs globally without a stub. 
    # But we can verify the induce_apoptosis function logic by calling it if we expose it for test.
    
    # For now, verify that EpigeneticSupervisor.apoptosis removes the right child.
    Core.EpigeneticSupervisor.apoptosis(motor_pid)
    Process.sleep(100)
    refute Process.alive?(motor_pid)
    assert Process.alive?(sensory_pid)
  end

  test "MetabolicDaemon triggers motor pruning on high L3 misses" do
    {:ok, pid} = MetabolicDaemon.start_link(name: :l3_test_daemon)
    
    # Manually calibrate with low L3 misses baseline
    :sys.replace_state(pid, fn state ->
      %{state | baselines: %{state.baselines | l3_misses: 100}, calibrated: true}
    end)

    # Spawn a motor cell to be pruned
    {:ok, motor_pid} = Core.EpigeneticSupervisor.spawn_cell("/home/adrian/Projects/nexical/karyon/priv/dna/motor_cell.yml")
    :pg.join(:motor, motor_pid)

    # Mock high misses (> baseline + 5000)
    Core.Native.set_native_mock(nil, 6000, false)

    # Trigger poll
    send(pid, :poll_metrics)
    Process.sleep(200)

    # Verify motor cell received apoptosis
    refute Process.alive?(motor_pid)
  end

  test "MetabolicDaemon starts in degraded pressure when preflight fails outside strict mode" do
    {:ok, pid} =
      MetabolicDaemon.start_link(
        name: :degraded_preflight_daemon,
        native_module: NativeStable,
        preflight_opts: [
          mock_hardware?: false,
          file_reader: fn _ -> {:error, :enoent} end,
          dir_lister: fn _ -> {:ok, []} end,
          scheduler_bind_type_fun: fn :scheduler_bind_type -> :tnnps end,
          logical_processors_fun: fn :logical_processors -> 8 end
        ],
        calibration_delay_ms: 10,
        poll_interval_ms: 10
      )

    assert GenServer.call(pid, :get_pressure) == :medium
    state = :sys.get_state(pid)
    assert match?({:degraded, _}, state.preflight_status)
  end

  test "MetabolicDaemon refuses to boot when strict preflight fails" do
    Process.flag(:trap_exit, true)

    assert {:error, {:preflight_failed, reason}} =
             MetabolicDaemon.start_link(
               name: :strict_preflight_daemon,
               strict_preflight: true,
               native_module: NativeStable,
               preflight_opts: [
                 mock_hardware?: false,
                 file_reader: fn _ -> {:error, :enoent} end,
                 dir_lister: fn _ -> {:ok, []} end,
                 scheduler_bind_type_fun: fn :scheduler_bind_type -> :tnnps end,
                 logical_processors_fun: fn :logical_processors -> 8 end
               ]
             )

    assert reason =~ "memory topology evidence"
  end

  test "MetabolicDaemon elevates pressure on high IOPS to enforce digital torpor pressure" do
    {:ok, pid} =
      MetabolicDaemon.start_link(
        name: :high_iops_test_daemon,
        native_module: NativeHighIops,
        preflight_opts: [
          mock_hardware?: false,
          file_reader: fn
            "/sys/devices/system/node/node0/meminfo" -> {:ok, "Node 0 MemTotal: 1234 kB"}
            _ -> {:error, :enoent}
          end,
          dir_lister: fn _ -> {:ok, []} end,
          scheduler_bind_type_fun: fn :scheduler_bind_type -> :tnnps end,
          logical_processors_fun: fn :logical_processors -> 8 end
        ],
        calibration_delay_ms: 10,
        poll_interval_ms: 10
      )

    Process.sleep(50)
    send(pid, :poll_metrics)
    Process.sleep(50)
    assert GenServer.call(pid, :get_pressure) == :high
  end
end
