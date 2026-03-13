defmodule Core.ChaosMonkey do
  @moduledoc """
  The Chaos Monkey. Responsibile for inducing programmed cell death (Apoptosis)
  randomly to verify the resilience of the OTP supervision tree and the 
  regenerative capabilities of the EpigeneticSupervisor.
  """
  use GenServer
  require Logger

  @interval_ms 5000

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Logger.info("[ChaosMonkey] Unleashed. Inducing periodic cellular disruption.")
    schedule_disruption()
    {:ok, state}
  end

  @impl true
  def handle_info(:disrupt, state) do
    induce_apoptosis()
    schedule_disruption()
    {:noreply, state}
  end

  defp schedule_disruption do
    Process.send_after(self(), :disrupt, @interval_ms)
  end

  defp induce_apoptosis do
    # 1. Gather all active StemCells from :pg
    cells = :pg.get_members(:stem_cell)
    
    # 2. Kill roughly 10%
    to_kill = Enum.take_random(cells, ceil(Enum.count(cells) * 0.1))

    unless Enum.empty?(to_kill) do
      Logger.warning("[ChaosMonkey] Terminating #{Enum.count(to_kill)} cells for apoptosis proving.")
      Enum.each(to_kill, fn pid -> 
        Process.exit(pid, :kill)
      end)
    end
  end
end
