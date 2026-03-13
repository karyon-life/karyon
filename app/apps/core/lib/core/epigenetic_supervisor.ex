defmodule Core.EpigeneticSupervisor do
  @moduledoc """
  The structural core of the Cytoplasm. Manages the dynamic lifecycle 
  (spawning and apoptosis) of Karyon Stem Cells via a DynamicSupervisor.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Leverage :one_for_one for high-churn operational Motor Cells
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Triggers localized Apoptosis (Programmed Cell Death).
  """
  def apoptosis(pid) do
    # Forceful termination, relying on process isolation
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
