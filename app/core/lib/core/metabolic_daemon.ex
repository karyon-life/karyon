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
  def init(_opts) do
    Logger.info("[MetabolicDaemon] Heartbeat initialized. Monitoring ERTS schedulers.")
    
    # Run mandatory pre-flight checks
    case Core.Preflight.run_checks() do
      :ok -> 
        # Schedule calibration after a short delay to allow system to settle
        Process.send_after(self(), :calibrate, 2000)
        schedule_poll()
        {:ok, %{pressure: :low, baselines: %{l3_misses: 0, run_queue: 0, iops: 0}, calibrated: false}}
      {:error, _reason} ->
        # In production this might halt the system. For now we log and proceed with warning.
        Logger.warning("[MetabolicDaemon] WARNING: Pre-flight checks failed. Proceeding in degraded state.")
        schedule_poll()
        {:ok, %{pressure: :low, baselines: %{l3_misses: 0, run_queue: 0, iops: 0}, calibrated: false}}
    end
  end

  @impl true
  def handle_call(:get_pressure, _from, state) do
    {:reply, state.pressure, state}
  end

  @impl true
  def handle_info(:calibrate, state) do
    Logger.info("[MetabolicDaemon] Calibrating metabolic baselines...")
    
    {l3, iops} = 
      if System.get_env("KARYON_MOCK_HARDWARE") == "1" do
        {1337, 42}
      else
        l3_val = 
          case Core.Native.read_l3_misses() do
            {:ok, val} -> val
            _ -> 0
          end
        
        iops_val = 
          case Core.Native.read_iops() do
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
    pressure = calculate_system_pressure(state)
    
    check_cpu_starvation(pressure)
    check_l3_cache_constriction(state)
    check_digital_torpor(state)
    check_numa_violation()

    schedule_poll()
    
    :telemetry.execute([:karyon, :metabolism, :poll], %{pressure: pressure_to_num(pressure)}, %{pressure: pressure})
    
    {:noreply, %{state | pressure: pressure}}
  end

  defp pressure_to_num(:low), do: 0
  defp pressure_to_num(:medium), do: 1
  defp pressure_to_num(:high), do: 2

  defp calculate_system_pressure(state) do
    run_queue_len = :erlang.statistics(:run_queue)
    baseline_rq = state.baselines.run_queue

    cond do
      run_queue_len > baseline_rq + 20 -> :high
      run_queue_len > baseline_rq + 10 -> :medium
      true -> :low
    end
  end

  defp check_cpu_starvation(pressure) do
    if pressure in [:medium, :high] do
      run_queue_len = :erlang.statistics(:run_queue)
      Logger.warning("[MetabolicDaemon] High Run Queue Detected: #{run_queue_len}. Triggering partial Apoptosis.")
      
      severity = if pressure == :high, do: "high", else: "medium"
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
      severity: severity
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

  defp check_l3_cache_constriction(state) do
    case Core.Native.read_l3_misses() do
      {:ok, misses} when misses > state.baselines.l3_misses + 5000 ->
        Logger.warning("[MetabolicDaemon] L3 Cache Constriction detected. Inducing Motor Apoptosis.")
        induce_apoptosis(:motor)
      _ ->
        :ok
    end
  end

  defp check_digital_torpor(state) do
    case Core.Native.read_iops() do
      {:ok, iops} when iops > state.baselines.iops + 1000 ->
        Logger.info("[MetabolicDaemon] High IOPS detected. Digital Torpor engaged.")
      _ ->
        :ok
    end
  end

  defp check_numa_violation do
    case Core.Native.read_numa_node() do
      {:ok, node} when node > 0 ->
        Logger.warning("[MetabolicDaemon] NUMA VIOLATION: Current Node #{node}. Bitemporal latency risk.")
        induce_apoptosis(:numa_migration)
      _ ->
        :ok
    end
  end

  defp induce_apoptosis(target_type) do
    # Ask the EpigeneticSupervisor to terminate cells of a specific type (graduated apoptosis)
    # Target specific cell types using :pg groups
    group = 
      case target_type do
        :motor -> :motor
        :sensory -> :sensory
        :orchestrator -> :orchestrator
        _ -> :undifferentiated
      end

    members = :pg.get_members(group)
    
    # Prune the first member found in the group
    case members do
      [target_pid | _] ->
        Logger.warning("[MetabolicDaemon] Executing Targeted Apoptosis on #{target_type} cell: #{inspect(target_pid)}")
        Core.EpigeneticSupervisor.apoptosis(target_pid)
      [] ->
        # fallback to dynamic supervisor children if group is empty
        Logger.info("[MetabolicDaemon] No cells found in group #{group}. Scanning DynamicSupervisor.")
        children = DynamicSupervisor.which_children(Core.EpigeneticSupervisor)
        case Enum.find(children, fn {_, pid, _, _} -> is_pid(pid) end) do
           {_, pid, _, _} -> 
             Logger.warning("[MetabolicDaemon] Executing Fallback Apoptosis on cell: #{inspect(pid)}")
             Core.EpigeneticSupervisor.apoptosis(pid)
           _ -> :ok
        end
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll_metrics, @poll_interval_ms)
  end
end
