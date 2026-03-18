defmodule Core.EpigeneticSupervisor do
  @moduledoc """
  The structural core of the Cytoplasm. Manages the dynamic lifecycle 
  (spawning and apoptosis) of Karyon Stem Cells via a DynamicSupervisor.
  """
  use DynamicSupervisor
  require Logger
  alias Core.MetabolismPolicy

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
    policy = MetabolismPolicy.current_policy()
    {dna, decision} = transcribe_environment(dna_source, Keyword.put(opts, :policy, policy))

    case policy.pressure do
      :high ->
        profile = MetabolismPolicy.spawn_profile(dna, policy)
        Logger.error("[EpigeneticSupervisor] METABOLIC STARVATION: Refusing to spawn new cell.")
        persist_differentiation(Map.put(decision, "spawn_admission", Map.put(profile, "status", "deferred")), nil)
        {:error, :metabolic_starvation}

      _ ->
        case MetabolismPolicy.admit_spawn(dna, policy) do
      {:error, profile} ->
        Logger.error("[EpigeneticSupervisor] METABOLIC STARVATION: Refusing to spawn new cell.")
        persist_differentiation(Map.put(decision, "spawn_admission", profile), nil)
        {:error, :metabolic_starvation}

      {:ok, profile} ->
        child_spec = %{
          id: Core.StemCell,
          start: {Core.StemCell, :start_link, [dna]},
          restart: :temporary
        }

        with {:ok, pid} <- DynamicSupervisor.start_child(__MODULE__, child_spec) do
          decision
          |> Map.put("spawn_admission", profile)
          |> persist_differentiation(pid)

          {:ok, pid}
        end
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
    explicit_pressure = Keyword.get(opts, :pressure)
    policy =
      case Keyword.fetch(opts, :policy) do
        {:ok, policy} -> policy
        :error when explicit_pressure in [:low, :medium, :high] -> MetabolismPolicy.build_policy(explicit_pressure)
        :error -> MetabolismPolicy.current_policy()
      end

    pressure = explicit_pressure || policy.pressure
    desired_role = normalize_role(Keyword.get(opts, :desired_role))
    source = Keyword.get(opts, :source, "epigenetic_supervisor")
    graph_context = normalize_graph_context(Keyword.get(opts, :graph_context, %{}))

    candidates =
      dna_source
      |> candidate_sources(opts)
      |> Enum.map(&differentiate/1)

    dna = select_candidate(candidates, policy, desired_role)

    decision = %{
      "lineage_id" => Core.DNA.lineage_id(dna),
      "role" => dna |> Core.DNA.role() |> Atom.to_string(),
      "pressure" => to_string(pressure),
      "source" => to_string(source),
      "status" => "selected",
      "dna_path" => dna.file_path,
      "metabolism_policy" => MetabolismPolicy.to_map(policy),
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

  defp select_candidate(candidates, policy, desired_role) do
    candidates
    |> maybe_filter_role(desired_role)
    |> Enum.min_by(fn dna ->
      profile = MetabolismPolicy.spawn_profile(dna, policy)
      admitted_penalty = if MetabolismPolicy.admitted?(profile), do: 0.0, else: 100.0
      slack_penalty = String.to_float("#{profile["cost"]}") - String.to_float("#{profile["budget"]}")
      speculative_penalty = if Core.DNA.speculative?(dna) and policy.pressure != :low, do: 1000.0, else: 0.0
      role_penalty = if desired_role && Core.DNA.role(dna) != desired_role, do: 25.0, else: 0.0
      admitted_penalty + max(slack_penalty, 0.0) + speculative_penalty + role_penalty
    end)
  end

  defp maybe_filter_role(candidates, nil), do: candidates

  defp maybe_filter_role(candidates, desired_role) do
    case Enum.filter(candidates, &(Core.DNA.role(&1) == desired_role)) do
      [] -> candidates
      filtered -> filtered
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
      |> Map.put("pid", if(pid, do: inspect(pid), else: "not_started"))
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
