defmodule Core.ChaosMonkey do
  @moduledoc """
  Simulation daemon that injects failure into the organism to test resilience.
  Periodic random killing of Stem Cells to exercise OTP Supervision trees.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, 5000)
    schedule_next_death(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:inject_failure, state) do
    Logger.warning("[ChaosMonkey] Selecting random cell for apoptosis...")
    
    # Get all active stem cells from pg
    case :pg.get_members(:stem_cell) do
      [] -> 
        Logger.info("[ChaosMonkey] No cells found to kill. Environment is sterile.")
      pids ->
        target = Enum.random(pids)
        Logger.error("[ChaosMonkey] Inducing sudden cell death on #{inspect(target)}")
        Process.exit(target, :kill)
    end

    schedule_next_death(state.interval)
    {:noreply, state}
  end

  defp schedule_next_death(interval) do
    Process.send_after(self(), :inject_failure, interval)
  end
end
