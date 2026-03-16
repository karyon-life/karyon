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

  defp perform_consolidation do
    Logger.info("[Rhizome.ConsolidationManager] STARTING SLEEP CYCLE: Consolidation in progress...")
    
    # 1. Trigger the bridge to XTDB to archive working state
    case Rhizome.Native.bridge_to_xtdb() do
      {:ok, msg} -> Logger.info("[Rhizome.ConsolidationManager] XTDB Bridge: #{msg}")
      {:error, reason} -> Logger.error("[Rhizome.ConsolidationManager] XTDB Bridge failed: #{inspect(reason)}")
    end

    # 2. Trigger graph optimization (Leiden) to generate Super-Nodes
    case Rhizome.Native.optimize_graph() do
      {:ok, msg} -> Logger.info("[Rhizome.ConsolidationManager] Optimizer: #{msg}")
      {:error, reason} -> Logger.error("[Rhizome.ConsolidationManager] Optimizer failed: #{inspect(reason)}")
    end

    # 3. Memory Relief: Prune nodes with extreme VFE or low utility
    perform_memory_relief()

    Logger.info("[Rhizome.ConsolidationManager] SLEEP CYCLE COMPLETE. Homeostasis restored.")
    schedule_next_check()
  end

  defp perform_memory_relief do
    Logger.info("[Rhizome.ConsolidationManager] Executing Memory Relief: Pruning high-VFE engrams.")
    
    # Prune cells with VFE > 0.8
    prune_query = "MATCH (c:Cell) WHERE c.vfe > 0.8 DETACH DELETE c"
    case Rhizome.Native.memgraph_query(prune_query) do
      {:ok, _} -> :ok
      err -> Logger.error("[Rhizome.ConsolidationManager] Memory Relief Failed: #{inspect(err)}")
    end
  end
end
