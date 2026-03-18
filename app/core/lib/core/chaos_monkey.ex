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
    probability = Keyword.get(opts, :probability, 0.2)
    max_victims = Keyword.get(opts, :max_victims, 1)
    Logger.info("[ChaosMonkey] Release the monkey! Apoptosis attacks scheduled every #{interval}ms.")
    schedule_attack(interval)
    {:ok, %{interval: interval, probability: probability, max_victims: max_victims}}
  end

  @impl true
  def handle_info(:attack, state) do
    execute_chaos(state)
    schedule_attack(state.interval)
    {:noreply, state}
  end

  defp schedule_attack(interval) do
    Process.send_after(self(), :attack, interval)
  end

  defp execute_chaos(state) do
    active_cells = Core.EpigeneticSupervisor.active_cells()

    victims =
      active_cells
      |> Enum.filter(fn _pid -> :rand.uniform() <= state.probability end)
      |> Enum.take(state.max_victims)

    if victims != [] do
      Enum.each(victims, fn pid ->
        Logger.warning("[ChaosMonkey] Random Apoptosis Attack on cell: #{inspect(pid)}")
        Core.EpigeneticSupervisor.apoptosis(pid)
      end)
    else
      Logger.info("[ChaosMonkey] No cells active. Skipping attack.")
    end
  end
end
