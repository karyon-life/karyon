defmodule Core.MetabolicDaemon do
  @moduledoc """
  The Metabolic Daemon. This gen_server continuously polls OS-level resources
  and BEAM metrics. If starvation or blockages occur, it triggers active apoptosis.
  """
  use GenServer
  require Logger

  @poll_interval_ms 1000

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    Logger.info("[MetabolicDaemon] Heartbeat initialized. Monitoring ERTS schedulers.")

    state = %{
      pressure: :low,
      consciousness_state: :awake,
      baselines: %{l3_misses: 0, run_queue: 0, iops: 0},
      calibrated: false,
      preflight_status: :ok,
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, @poll_interval_ms),
      calibration_delay_ms: Keyword.get(opts, :calibration_delay_ms, 2000),
      native_module: Keyword.get(opts, :native_module, Core.Native),
      strict_preflight: Keyword.get(opts, :strict_preflight, strict_preflight?()),
      preflight_opts: Keyword.get(opts, :preflight_opts, [])
    }

    case Core.Preflight.run_checks(Keyword.put(state.preflight_opts, :native_module, state.native_module)) do
      :ok ->
        Process.send_after(self(), :calibrate, state.calibration_delay_ms)
        schedule_poll(state)
        {:ok, state}

      {:error, reason} when state.strict_preflight ->
        Logger.error("[MetabolicDaemon] Pre-flight checks failed in strict mode. Refusing to boot.")
        {:stop, {:preflight_failed, reason}}

      {:error, reason} ->
        Logger.warning("[MetabolicDaemon] WARNING: Pre-flight checks failed. Proceeding in degraded state.")
        Process.send_after(self(), :calibrate, state.calibration_delay_ms)
        schedule_poll(state)
        {:ok, %{state | pressure: :medium, preflight_status: {:degraded, reason}}}
    end
  end

  @impl true
  def handle_call(:get_pressure, _from, state) do
    {:reply, state.pressure, state}
  end

  @impl true
  def handle_call(:get_policy, _from, state) do
    {:reply, metabolic_policy(state.pressure), state}
  end

  @impl true
  def handle_call(:get_runtime_status, _from, state) do
    {:reply,
     %{
       pressure: state.pressure,
       consciousness_state: state.consciousness_state,
       membrane_open: membrane_open?(state.consciousness_state),
       motor_output_open: motor_output_open?(state.consciousness_state),
       preflight_status: state.preflight_status,
       calibrated: state.calibrated,
       strict_preflight: state.strict_preflight
     }, state}
  end

  @impl true
  def handle_call(:get_membrane_state, _from, state) do
    {:reply,
     %{
       consciousness_state: state.consciousness_state,
       membrane_open: membrane_open?(state.consciousness_state),
       motor_output_open: motor_output_open?(state.consciousness_state)
     }, state}
  end

  @impl true
  def handle_info(:calibrate, state) do
    Logger.info("[MetabolicDaemon] Calibrating metabolic baselines...")
    
    {l3, iops} = 
      if System.get_env("KARYON_MOCK_HARDWARE") == "1" do
        {1337, 42}
      else
        l3_val = 
          case state.native_module.read_l3_misses() do
            {:ok, val} -> val
            _ -> 0
          end
        
        iops_val = 
          case state.native_module.read_iops() do
            {:ok, val} -> val
            _ -> 0
          end
        {l3_val, iops_val}
      end
    
    rq = :erlang.statistics(:run_queue)

    baselines = %{
      l3_misses: l3,
      run_queue: rq,
      iops: iops
    }

    Logger.info("[MetabolicDaemon] Baselines established: L3=#{l3}, RQ=#{rq}, IOPS=#{iops}")
    {:noreply, %{state | baselines: baselines, calibrated: true}}
  end

  @impl true
  def handle_info(:poll_metrics, state) do
    snapshot = collect_metric_snapshot(state)
    pressure = calculate_system_pressure(state, snapshot)
    consciousness_state = determine_consciousness_state(state, snapshot)
    
    check_cpu_starvation(pressure)
    check_l3_cache_constriction(state, snapshot)
    check_digital_torpor(state, snapshot)
    check_numa_violation(state, snapshot)

    schedule_poll(state)
    
    :telemetry.execute(
      [:karyon, :metabolism, :poll],
      %{pressure: pressure_to_num(pressure)},
      %{
        pressure: pressure,
        l3_misses: snapshot.l3_misses,
        run_queue: snapshot.run_queue,
        iops: snapshot.iops,
        atp: atp_level(pressure),
        consciousness_state: consciousness_state,
        membrane_open: membrane_open?(consciousness_state),
        motor_output_open: motor_output_open?(consciousness_state),
        policy: Core.MetabolismPolicy.to_map(metabolic_policy(pressure)),
        preflight_status: state.preflight_status
      }
    )
    
    {:noreply, %{state | pressure: pressure, consciousness_state: consciousness_state}}
  end

  defp pressure_to_num(:low), do: 0
  defp pressure_to_num(:medium), do: 1
  defp pressure_to_num(:high), do: 2

  defp calculate_system_pressure(state, snapshot) do
    run_queue_len = snapshot.run_queue
    baseline_rq = state.baselines.run_queue
    iops_pressure = iops_pressure(state, snapshot)
    preflight_pressure = if match?({:degraded, _}, state.preflight_status), do: :medium, else: :low
    run_queue_pressure =
      cond do
        run_queue_len > baseline_rq + 20 -> :high
        run_queue_len > baseline_rq + 10 -> :medium
        true -> :low
      end

    max_pressure([run_queue_pressure, iops_pressure, preflight_pressure])
  end

  defp check_cpu_starvation(pressure) do
    if pressure in [:medium, :high] do
      run_queue_len = :erlang.statistics(:run_queue)
      Logger.warning("[MetabolicDaemon] High Run Queue Detected: #{run_queue_len}. Triggering partial Apoptosis.")
      
      severity = if pressure == :high, do: 1.0, else: 0.6
      broadcast_spike("cpu", run_queue_len, 10.0, severity)
      
      induce_apoptosis(:generic)
    end
  end

  defp broadcast_spike(type, value, threshold, severity) do
    msg = %Karyon.NervousSystem.MetabolicSpike{
      metric_type: type,
      value: value * 1.0,
      threshold: threshold * 1.0,
      timestamp: System.system_time(:second),
      severity: severity,
      source: "metabolic_daemon"
    }
    
    # We'll use a globally registered endocrine gnat connection if available, 
    # or start a transient one for now. In production this PID would be injected.
    case GenServer.whereis(:endocrine_gnat) do
      nil -> :ok
      pid -> 
        case Karyon.NervousSystem.MetabolicSpike.encode(msg) do
          {:ok, binary} ->
            NervousSystem.Endocrine.publish_gradient(pid, "metabolic.spike", binary)
          {:error, reason} ->
            Logger.error("[MetabolicDaemon] Failed to encode spike: #{inspect(reason)}")
        end
    end
  end

  defp check_l3_cache_constriction(state, snapshot) do
    case snapshot.l3_misses do
      misses when is_integer(misses) and misses > state.baselines.l3_misses + 5000 ->
        Logger.warning("[MetabolicDaemon] L3 Cache Constriction detected. Inducing Motor Apoptosis.")
        induce_apoptosis(:motor)
      _ ->
        :ok
    end
  end

  defp check_digital_torpor(state, snapshot) do
    case snapshot.iops do
      iops when is_integer(iops) and iops > state.baselines.iops + 1000 ->
        Logger.info("[MetabolicDaemon] High IOPS detected. Digital Torpor engaged.")
        broadcast_spike("iops", iops, state.baselines.iops + 1000, 1.0)
      _ ->
        :ok
    end
  end

  defp check_numa_violation(_state, snapshot) do
    case snapshot.numa_node do
      node when is_integer(node) and node > 0 ->
        Logger.warning("[MetabolicDaemon] NUMA VIOLATION: Current Node #{node}. Bitemporal latency risk.")
        induce_apoptosis(:numa_migration)
      _ ->
        :ok
    end
  end

  defp induce_apoptosis(target_type) do
    case apoptosis_target(target_type) do
      nil ->
        Logger.info("[MetabolicDaemon] No eligible cells found for #{target_type} apoptosis.")

      target_pid ->
        Logger.warning("[MetabolicDaemon] Executing Targeted Apoptosis on #{target_type} cell: #{inspect(target_pid)}")
        Core.EpigeneticSupervisor.apoptosis(target_pid)
    end
  end

  defp apoptosis_target(target_type) do
    Core.EpigeneticSupervisor.active_cells()
    |> Enum.map(&runtime_snapshot/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(target_matches?(&1, target_type)))
    |> Enum.sort_by(fn snapshot ->
      {
        snapshot.safety_critical,
        snapshot.status != :torpor,
        apoptosis_priority(snapshot.role)
      }
    end)
    |> List.first()
    |> case do
      nil -> nil
      snapshot -> snapshot.pid
    end
  end

  defp runtime_snapshot(pid) do
    runtime = GenServer.call(pid, :get_runtime_state)

    %{
      pid: pid,
      role: runtime[:role],
      status: runtime[:status],
      safety_critical: runtime[:safety_critical]
    }
  rescue
    _ -> nil
  end

  defp target_matches?(snapshot, :generic), do: not snapshot.safety_critical
  defp target_matches?(snapshot, :numa_migration), do: not snapshot.safety_critical
  defp target_matches?(snapshot, target_type), do: snapshot.role == target_type

  defp apoptosis_priority(:motor), do: 0
  defp apoptosis_priority(:sensory), do: 1
  defp apoptosis_priority(:architect_planner), do: 2
  defp apoptosis_priority(:orchestrator), do: 3
  defp apoptosis_priority(_), do: 4

  defp iops_pressure(state, snapshot) do
    case snapshot.iops do
      iops when is_integer(iops) and iops > state.baselines.iops + 1000 -> :high
      _ -> :low
    end
  end

  defp collect_metric_snapshot(state) do
    %{
      l3_misses: metric_value(fn -> state.native_module.read_l3_misses() end),
      run_queue: :erlang.statistics(:run_queue),
      iops: metric_value(fn -> state.native_module.read_iops() end),
      numa_node: metric_value(fn -> state.native_module.read_numa_node() end)
    }
  end

  defp metric_value(reader_fun) do
    case reader_fun.() do
      {:ok, value} -> value
      _ -> nil
    end
  end

  defp atp_level(pressure) do
    max(0.0, 1.0 - pressure_to_num(pressure) * 0.3)
  end

  defp determine_consciousness_state(state, snapshot) do
    cond do
      iops_pressure(state, snapshot) == :high -> :torpor
      simulation_daemon_dreaming?() -> :dreaming
      true -> :awake
    end
  end

  defp simulation_daemon_dreaming? do
    if Code.ensure_loaded?(Core.SimulationDaemon) do
      Core.SimulationDaemon.dreaming?()
    else
      false
    end
  rescue
    _ -> false
  catch
    :exit, _ -> false
  end

  defp membrane_open?(:awake), do: true
  defp membrane_open?(_), do: false

  defp motor_output_open?(:awake), do: true
  defp motor_output_open?(_), do: false

  defp metabolic_policy(pressure) do
    Core.MetabolismPolicy.build_policy(pressure)
  end

  defp max_pressure(pressures) do
    Enum.max_by(pressures, &pressure_to_num/1, fn -> :low end)
  end

  defp schedule_poll(state) do
    Process.send_after(self(), :poll_metrics, state.poll_interval_ms)
  end

  defp strict_preflight? do
    Application.get_env(:core, :strict_preflight, false) or
      System.get_env("KARYON_STRICT_PREFLIGHT") in ["1", "true"]
  end
end
