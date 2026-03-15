defmodule Core.ChaosMonkey do
  @moduledoc """
  The Chaos Monkey. Dramatically tests the resilience of Karyon's cellular autonomous agents
  by sporadically executing programmed apoptosis (termination) on active cells.
  """
  use GenServer
  require Logger

  @default_interval 5000 # 5 seconds

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    Logger.info("[ChaosMonkey] Release the monkey! Apoptosis attacks scheduled every #{interval}ms.")
    schedule_attack(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:attack, state) do
    execute_chaos()
    schedule_attack(state.interval)
    {:noreply, state}
  end

  defp schedule_attack(interval) do
    Process.send_after(self(), :attack, interval)
  end

  defp execute_chaos do
    # Find all active cells in the EpigeneticSupervisor
    children = DynamicSupervisor.which_children(Core.EpigeneticSupervisor)
    
    active_cells = Enum.filter(children, fn {_, pid, _, _} -> is_pid(pid) end)

    if length(active_cells) > 0 do
      # Select a random victim for apoptosis
      {_, pid, _, _} = Enum.random(active_cells)
      
      Logger.warning("[ChaosMonkey] 🐵 Random Apoptosis Attack on cell: #{inspect(pid)}")
      Core.EpigeneticSupervisor.apoptosis(pid)
    else
      Logger.info("[ChaosMonkey] No cells active. Skipping attack.")
    end
  end
end
