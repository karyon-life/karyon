defmodule Rhizome.ConsolidationManager do
  @moduledoc """
  Orchestrates the "Sleep Cycle" (Consolidation) of the Karyon organism.
  Monitors metabolic state and system idle time to trigger background graph optimization.
  """
  use GenServer
  require Logger

  @sleep_cycle_interval_ms 60_000 # Check every minute

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def run_once(opts \\ []) do
    perform_consolidation(opts)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Rhizome.ConsolidationManager] Sleep Cycle Daemon initialized.")
    schedule_next_check()
    {:ok, %{last_consolidation: nil}}
  end

  @impl true
  def handle_info(:check_consolidation_window, state) do
    if is_system_dormant?() do
      perform_consolidation()
      {:noreply, %{state | last_consolidation: DateTime.utc_now()}}
    else
      Logger.debug("[Rhizome.ConsolidationManager] System active. Postponing Sleep Cycle.")
      schedule_next_check()
      {:noreply, state}
    end
  end

  defp schedule_next_check do
    Process.send_after(self(), :check_consolidation_window, @sleep_cycle_interval_ms)
  end

  defp is_system_dormant? do
    # Check metabolic pressure. Sleep cycle only runs when pressure is :low
    case GenServer.whereis(Core.MetabolicDaemon) do
      nil -> true
      pid -> GenServer.call(pid, :get_pressure) == :low
    end
  end

  defp perform_consolidation(opts \\ []) do
    native_module = Keyword.get(opts, :native_module, Rhizome.Native)
    logger_fun = Keyword.get(opts, :logger_fun, &Logger.info/1)

    Logger.info("[Rhizome.ConsolidationManager] STARTING SLEEP CYCLE: Consolidation in progress...")

    started_at = System.monotonic_time()

    bridge_result =
      case native_module.bridge_to_xtdb() do
        {:ok, %{message: msg} = result} ->
          logger_fun.("[Rhizome.ConsolidationManager] XTDB Bridge: #{msg}")
          {:ok, result}

        {:error, reason} ->
          Logger.error("[Rhizome.ConsolidationManager] XTDB Bridge failed: #{inspect(reason)}")
          {:error, reason}
      end

    optimize_result =
      case native_module.optimize_graph() do
        {:ok, msg} ->
          logger_fun.("[Rhizome.ConsolidationManager] Optimizer: #{msg}")
          {:ok, msg}

        {:error, reason} ->
          Logger.error("[Rhizome.ConsolidationManager] Optimizer failed: #{inspect(reason)}")
          {:error, reason}
      end

    memory_relief_result = perform_memory_relief(native_module)

    duration_ms =
      System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond)

    Logger.info("[Rhizome.ConsolidationManager] SLEEP CYCLE COMPLETE. Homeostasis restored.")

    if Keyword.get(opts, :schedule_next?, true) do
      schedule_next_check()
    end

    %{
      bridge_to_xtdb: bridge_result,
      optimize_graph: optimize_result,
      memory_relief: memory_relief_result,
      duration_ms: duration_ms
    }
  end

  defp perform_memory_relief(native_module) do
    Logger.info("[Rhizome.ConsolidationManager] Executing Memory Relief: Pruning high-VFE engrams.")
    
    # Prune cells with VFE > 0.8
    prune_query = "MATCH (c:Cell) WHERE c.vfe > 0.8 DETACH DELETE c"
    case native_module.memgraph_query(prune_query) do
      {:ok, _} -> :ok
      err ->
        Logger.error("[Rhizome.ConsolidationManager] Memory Relief Failed: #{inspect(err)}")
        err
    end
  end
end
