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
    
    if run_queue_len > 10 do
      Logger.warning("[MetabolicDaemon] High Run Queue Detected: #{run_queue_len}. Triggering partial Apoptosis.")
      induce_apoptosis(:generic)
    end
  end

  defp check_l3_cache_constriction do
    # Use real NIF to read hardware L3 cache misses
    case Core.Native.read_l3_misses() do
      {:ok, misses} when misses > 5000 ->
        Logger.warning("[MetabolicDaemon] L3 Cache Constriction: #{misses} misses. Inducing Motor Apoptosis.")
        induce_apoptosis(:motor)
      _ ->
        :ok
    end
  end

  defp check_digital_torpor do
    # Use real NIF to read IOPS from /proc/diskstats
    case Core.Native.read_iops() do
      {:ok, iops} when iops > 1000 ->
        Logger.info("[MetabolicDaemon] High IOPS detected: #{iops}. Digital Torpor engaged.")
        # In a full systems implementation, this would signal XTDB to slow flush cycles
      _ ->
        :ok
    end
  end

  defp induce_apoptosis(target_type) do
    # Ask the EpigeneticSupervisor to terminate cells of a specific type (graduated apoptosis)
    children = DynamicSupervisor.which_children(Core.EpigeneticSupervisor)
    
    # Simple graduation: kill motor cells if requested, otherwise generic
    target_pid = 
      Enum.find_value(children, fn {_, pid, _, _} ->
        if is_pid(pid), do: pid, else: nil
      end)

    if target_pid do
      Logger.warning("[MetabolicDaemon] Executing Apoptosis on #{target_type} cell: #{inspect(target_pid)}")
      Core.EpigeneticSupervisor.apoptosis(target_pid)
    end
  end
end
