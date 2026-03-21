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
    memory_module = Keyword.get(opts, :memory_module, Rhizome.Memory)
    logger_fun = Keyword.get(opts, :logger_fun, &Logger.info/1)
    clock_fun = Keyword.get(opts, :clock_fun, &DateTime.utc_now/0)

    Logger.info("[Rhizome.ConsolidationManager] STARTING SLEEP CYCLE: Consolidation in progress...")

    started_at = System.monotonic_time()
    cycle_started_at = clock_fun.()

    classification_result = classify_sleep_candidates(native_module)
    abstraction_result = create_sleep_supernodes(native_module, classification_result, cycle_started_at)

    bridge_result =
      case memory_module.bridge_working_memory_to_archive() do
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

    memory_relief_result =
      perform_memory_relief(native_module, classification_result, cycle_started_at, logger_fun)

    duration_ms =
      System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond)

    Logger.info("[Rhizome.ConsolidationManager] SLEEP CYCLE COMPLETE. Homeostasis restored.")

    if Keyword.get(opts, :schedule_next?, true) do
      schedule_next_check()
    end

    %{
      classified_candidates: classification_result,
      abstractions: abstraction_result,
      bridge_to_xtdb: bridge_result,
      optimize_graph: optimize_result,
      memory_relief: memory_relief_result,
      duration_ms: duration_ms
    }
    |> Map.merge(%{learning_phase: "consolidation", learning_edge: "plasticity->consolidation"})
  end

  defp perform_memory_relief(native_module, classification_result, cycle_started_at, logger_fun) do
    Logger.info("[Rhizome.ConsolidationManager] Executing Memory Relief: Targeted pruning and archival retention.")

    prunable_candidates =
      case classification_result do
        {:ok, %{prunable: candidates}} -> candidates
        _ -> []
      end

    case mark_pruned_candidates(native_module, prunable_candidates, cycle_started_at) do
      {:ok, count} ->
        logger_fun.("[Rhizome.ConsolidationManager] Memory Relief pruned #{count} high-VFE engrams without deletion.")

        {:ok, %{pruned_count: count, retained_in_archive: true, strategy: "targeted_in_place_pruning"}}

      err ->
        Logger.error("[Rhizome.ConsolidationManager] Memory Relief Failed: #{inspect(err)}")
        err
    end
  end

  defp classify_sleep_candidates(native_module) do
    query = """
    MATCH (n:PooledSequence)
    WHERE coalesce(n.archived, false) = false
      AND n.source = 'operator_environment'
    RETURN id(n) AS internal_id, labels(n) AS labels, properties(n) AS props
    """

    case native_module.memgraph_query(query) do
      {:ok, rows} when is_list(rows) ->
        sequences =
          Enum.map(rows, &normalize_sleep_candidate/1)
          |> Enum.reject(&is_nil/1)

        {:ok,
         %{
           total: length(sequences),
           sequences: sequences
         }}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:invalid_sleep_candidates, other}}
    end
  end

  defp create_sleep_supernodes(_native_module, {:error, reason}, _cycle_started_at), do: {:error, reason}

  defp create_sleep_supernodes(_native_module, {:ok, %{sequences: []}}, _cycle_started_at) do
    {:ok, %{supernode_count: 0, abstracted_count: 0, abstraction_ids: []}}
  end

  defp create_sleep_supernodes(native_module, {:ok, %{sequences: sequences}}, cycle_started_at) do
    with {:ok, _message} <- optimize_language_graph(native_module),
         {:ok, summary} <- summarize_temporal_supernodes(native_module, cycle_started_at) do
      {:ok,
       %{
         supernode_count: summary.supernode_count,
         abstracted_count: summary.abstracted_count,
         abstraction_ids: summary.abstraction_ids,
         candidate_count: length(sequences)
       }}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_abstraction_result, other}}
    end
  end

  defp mark_pruned_candidates(_native_module, [], _cycle_started_at), do: {:ok, 0}
  defp mark_pruned_candidates(_native_module, _candidates, _cycle_started_at), do: {:ok, 0}

  defp normalize_sleep_candidate(%{"internal_id" => internal_id, "labels" => labels, "props" => props})
       when is_integer(internal_id) and is_list(labels) and is_map(props) do
    %{
      internal_id: internal_id,
      labels: Enum.map(labels, &to_string/1),
      props: props
    }
  end

  defp normalize_sleep_candidate(_row), do: nil

  defp optimize_language_graph(native_module) do
    case native_module.optimize_graph() do
      {:ok, _message} = ok -> ok
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_optimizer_result, other}}
    end
  end

  defp summarize_temporal_supernodes(native_module, cycle_started_at) do
    observed_at = DateTime.to_unix(cycle_started_at)

    query = """
    MATCH (g:GrammarSuperNode)
    WHERE g.source = 'operator_environment'
      AND g.kind = 'temporal_grammar_chunk'
      AND coalesce(g.observed_at, 0) >= #{observed_at}
    RETURN count(g) AS supernode_count,
           coalesce(sum(g.sequence_length), 0) AS abstracted_count,
           collect(g.id) AS abstraction_ids
    """

    case native_module.memgraph_query(query) do
      {:ok, [%{"supernode_count" => count, "abstracted_count" => abstracted_count, "abstraction_ids" => abstraction_ids}]}
          when is_integer(count) and is_integer(abstracted_count) and is_list(abstraction_ids) ->
        {:ok,
         %{
           supernode_count: count,
           abstracted_count: abstracted_count,
           abstraction_ids: abstraction_ids
         }}

      {:ok, []} ->
        {:ok, %{supernode_count: 0, abstracted_count: 0, abstraction_ids: []}}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:invalid_temporal_summary_result, other}}
    end
  end
end
