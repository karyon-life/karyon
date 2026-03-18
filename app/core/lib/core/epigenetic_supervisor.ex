defmodule Core.EpigeneticSupervisor do
  @moduledoc """
  The structural core of the Cytoplasm. Manages the dynamic lifecycle 
  (spawning and apoptosis) of Karyon Stem Cells via a DynamicSupervisor.
  """
  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Leverage :one_for_one for high-churn operational Motor Cells
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Spawns a new cell by injecting a declarative YAML configuration into the sterile core.
  Checks current metabolic pressure before spawning.
  """
  def spawn_cell(dna_file_path \\ "config/genetics/base_stem_cell.yml") do
    # Logic to refuse spawning if system is under high metabolic pressure
    case get_metabolic_pressure() do
      :high ->
        Logger.error("[EpigeneticSupervisor] METABOLIC STARVATION: Refusing to spawn new cell.")
        {:error, :metabolic_starvation}
      _ ->
        child_spec = %{
          id: Core.StemCell,
          start: {Core.StemCell, :start_link, [dna_file_path]},
          restart: :temporary
        }
        DynamicSupervisor.start_child(__MODULE__, child_spec)
    end
  end

  @doc """
  Returns the live cells currently advertising a given role through :pg routing topics.
  """
  def members_for_role(role) do
    Core.StemCell.role_members(role)
  end

  @doc """
  Selects a live peer for the requested role using decentralized gradient sensing.
  """
  def discover_cell(role, opts \\ []) do
    Core.StemCell.sense_gradient(role, opts)
  end

  defp get_metabolic_pressure do
    # Query the MetabolicDaemon or ETS for current pressure
    case GenServer.whereis(Core.MetabolicDaemon) do
      nil -> :low
      pid -> GenServer.call(pid, :get_pressure)
    end
  end

  @doc """
  Triggers localized Apoptosis (Programmed Cell Death).
  """
  def apoptosis(pid) do
    # Forceful termination, relying on process isolation
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
