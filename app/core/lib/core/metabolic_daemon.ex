defmodule Core.MetabolicDaemon do
  @moduledoc """
  The Metabolic Daemon. This gen_server continuously polls OS-level resources
  and BEAM metrics. If starvation or blockages occur, it triggers active apoptosis.
  """
  use GenServer
  require Logger

  @poll_interval_ms 1000
  @max_run_queue_wait_ms 5

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Logger.info("[MetabolicDaemon] Heartbeat initialized. Monitoring ERTS schedulers.")
    schedule_poll()
    {:ok, state}
  end

  @impl true
  def handle_info(:poll_metrics, state) do
    check_cpu_starvation()
    check_l3_cache_constriction()
    check_digital_torpor()

    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll_metrics, @poll_interval_ms)
  end

  defp check_cpu_starvation do
    # Sample Erlang scheduler run queue over time.
    run_queue_len = :erlang.statistics(:run_queue)
    
    if run_queue_len > 10 do # Arbitrary High-Water mark for the whole VM
      Logger.warning("[MetabolicDaemon] High Run Queue Detected: #{run_queue_len}. Triggering partial Apoptosis.")
      
      # Ask the EpigeneticSupervisor to terminate lowest-utility PIDs (localized apoptosis)
      children = DynamicSupervisor.which_children(Core.EpigeneticSupervisor)
      
      case children do
        [{_, pid, _, _} | _] when is_pid(pid) ->
          Logger.warning("[MetabolicDaemon] Inducing Apoptosis on PID: #{inspect(pid)}")
          Core.EpigeneticSupervisor.apoptosis(pid)
        _ ->
          :ok
      end
    end
  end

  defp check_l3_cache_constriction do
    # Sample logic: simulate dropping ambient NATS telemetry if memory limits suffocate.
    # In a real system, we'd use a NIF to read CPU performance counters (perf_event_open).
    
    # Mock: 1% chance of a "transient L3 spike" for simulation purposes
    if :rand.uniform(100) == 1 do
      Logger.warning("[MetabolicDaemon] L3 Cache Constriction detected. Shedding peripheral telemetry.")
      # In Phase 5+, we'd actually signal NervousSystem.Endocrine to dampen NATS traffic
    end
    :ok
  end

  defp check_digital_torpor do
    # Sample logic: shed speculative cells if IO limits are blocked on XTDB/Graph.
    # In a real system, we'd monitor XTDB commit latency or Virtio-blk wait times.
    
    # Mock: trigger torpor if the scheduler is heavily loaded (as a proxy for IO wait)
    {total_run_queue, _} = :erlang.statistics(:run_queue_lengths)
    if total_run_queue > 20 do
      Logger.info("[MetabolicDaemon] Digital Torpor engaged. Suspending low-priority IO cycles.")
    end
    :ok
  end
end
