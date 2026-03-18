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
  def spawn_cell(dna_source \\ "config/genetics/base_stem_cell.yml", opts \\ []) do
    pressure = get_metabolic_pressure()

    case pressure do
      :high ->
        Logger.error("[EpigeneticSupervisor] METABOLIC STARVATION: Refusing to spawn new cell.")
        {:error, :metabolic_starvation}

      _ ->
        {dna, decision} = transcribe_environment(dna_source, Keyword.put(opts, :pressure, pressure))

        child_spec = %{
          id: Core.StemCell,
          start: {Core.StemCell, :start_link, [dna]},
          restart: :temporary
        }

        with {:ok, pid} <- DynamicSupervisor.start_child(__MODULE__, child_spec) do
          persist_differentiation(decision, pid)
          {:ok, pid}
        end
    end
  end

  @doc """
  Normalizes a DNA asset into the epigenetic control-plane contract used for differentiation.
  """
  def differentiate(dna_source) do
    case dna_source do
      %Core.DNA{} = dna -> dna
      path when is_binary(path) -> Core.DNA.load!(path)
    end
  end

  @doc """
  Chooses a differentiated DNA variant based on environmental pressure and context.
  Returns the selected DNA and its persisted decision payload.
  """
  def transcribe_environment(dna_source, opts \\ []) do
    pressure = Keyword.get(opts, :pressure, get_metabolic_pressure())
    desired_role = normalize_role(Keyword.get(opts, :desired_role))
    source = Keyword.get(opts, :source, "epigenetic_supervisor")
    graph_context = normalize_graph_context(Keyword.get(opts, :graph_context, %{}))

    candidates =
      dna_source
      |> candidate_sources(opts)
      |> Enum.map(&differentiate/1)

    dna = select_candidate(candidates, pressure, desired_role)

    decision = %{
      "lineage_id" => Core.DNA.lineage_id(dna),
      "role" => dna |> Core.DNA.role() |> Atom.to_string(),
      "pressure" => to_string(pressure),
      "source" => to_string(source),
      "status" => "selected",
      "dna_path" => dna.file_path,
      "desired_role" => desired_role && Atom.to_string(desired_role),
      "graph_context" => graph_context,
      "candidate_roles" => Enum.map(candidates, fn candidate -> candidate |> Core.DNA.role() |> Atom.to_string() end)
    }

    {dna, decision}
  end

  @doc """
  Returns the explicit DNA-derived control-plane contract for a cell specification.
  """
  def control_plane_for(dna_source) do
    dna_source
    |> differentiate()
    |> Map.fetch!(:control_plane)
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

  @doc """
  Returns the live child PIDs currently supervised as active cells.
  """
  def active_cells do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
    |> Enum.filter(&Process.alive?/1)
  end

  @doc """
  Returns the current number of live supervised cells.
  """
  def active_cell_count do
    active_cells()
    |> length()
  end

  defp candidate_sources(dna_source, opts) do
    explicit_variants = Keyword.get(opts, :variants, [])

    case explicit_variants do
      [] -> List.wrap(dna_source)
      variants -> variants
    end
  end

  defp select_candidate(candidates, pressure, desired_role) do
    candidates
    |> maybe_filter_role(desired_role)
    |> Enum.min_by(fn dna ->
      atp = Core.DNA.atp_requirement(dna)
      speculative_penalty = if Core.DNA.speculative?(dna), do: 100.0, else: 0.0
      role_penalty = if desired_role && Core.DNA.role(dna) != desired_role, do: 50.0, else: 0.0

      pressure_penalty =
        case pressure do
          :medium -> atp * 10.0 + speculative_penalty
          :low -> atp + role_penalty
          _ -> atp + role_penalty
        end

      pressure_penalty
    end)
  end

  defp maybe_filter_role(candidates, nil), do: candidates

  defp maybe_filter_role(candidates, desired_role) do
    case Enum.filter(candidates, &(Core.DNA.role(&1) == desired_role)) do
      [] -> candidates
      filtered -> filtered
    end
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
    if Process.alive?(pid) do
      GenServer.call(pid, {:lifecycle_transition, :terminated, %{"source" => "epigenetic_supervisor"}})
    end

    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  defp persist_differentiation(decision, pid) do
    event =
      decision
      |> Map.put("pid", inspect(pid))
      |> Map.put("recorded_at", System.system_time(:second))

    case memory_module().submit_differentiation_event(event) do
      {:ok, _} -> :ok
      {:error, reason} ->
        Logger.warning("[EpigeneticSupervisor] Failed to persist differentiation event: #{inspect(reason)}")
        :ok
    end
  end

  defp memory_module do
    Application.get_env(:core, :memory_module, Rhizome.Memory)
  end

  defp normalize_role(nil), do: nil
  defp normalize_role(role) when is_atom(role), do: role
  defp normalize_role(role) when is_binary(role), do: String.to_atom(role)
  defp normalize_role(_role), do: nil

  defp normalize_graph_context(graph_context) when is_map(graph_context) do
    Map.new(graph_context, fn {key, value} -> {to_string(key), normalize_graph_value(value)} end)
  end

  defp normalize_graph_context(_graph_context), do: %{}
  defp normalize_graph_value(value) when is_map(value), do: normalize_graph_context(value)
  defp normalize_graph_value(value) when is_list(value), do: Enum.map(value, &normalize_graph_value/1)
  defp normalize_graph_value(value), do: value
end
