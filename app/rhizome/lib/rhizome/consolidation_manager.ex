defmodule Rhizome.ConsolidationManager do
  @moduledoc """
  Orchestrates the "Sleep Cycle" (Consolidation) of the Karyon organism.
  Monitors metabolic state and system idle time to trigger background graph optimization.
  """
  use GenServer
  require Logger
  @high_vfe_threshold 0.8

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

        {:ok,
         %{
           pruned_count: count,
           retained_in_archive: true,
           strategy: "targeted_in_place_pruning"
         }}

      err ->
        Logger.error("[Rhizome.ConsolidationManager] Memory Relief Failed: #{inspect(err)}")
        err
    end
  end

  defp classify_sleep_candidates(native_module) do
    query = """
    MATCH (n)
    WHERE coalesce(n.archived, false) = false
    RETURN id(n) AS internal_id, labels(n) AS labels, properties(n) AS props
    """

    case native_module.memgraph_query(query) do
      {:ok, rows} when is_list(rows) ->
        candidates =
          Enum.map(rows, &normalize_sleep_candidate/1)
          |> Enum.reject(&is_nil/1)

        {prunable, retainable} = Enum.split_with(candidates, &candidate_prunable?/1)

        {:ok,
         %{
           total: length(candidates),
           prunable: prunable,
           retainable: retainable
         }}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:invalid_sleep_candidates, other}}
    end
  end

  defp create_sleep_supernodes(_native_module, {:error, reason}, _cycle_started_at), do: {:error, reason}

  defp create_sleep_supernodes(_native_module, {:ok, %{prunable: []}}, _cycle_started_at) do
    {:ok, %{supernode_count: 0, abstracted_count: 0, abstraction_ids: []}}
  end

  defp create_sleep_supernodes(native_module, {:ok, %{prunable: prunable}}, cycle_started_at) do
    run_id = sleep_supernode_id(cycle_started_at)
    label_summary = prunable |> Enum.flat_map(& &1.labels) |> Enum.uniq() |> Enum.sort()
    node_ids = Enum.map(prunable, & &1.internal_id)
    created_at = DateTime.to_iso8601(cycle_started_at)

    query = """
    MERGE (s:SleepSuperNode {id: '#{escape_cypher(run_id)}'})
    SET s.kind = 'sleep_consolidation',
        s.created_at = '#{escape_cypher(created_at)}',
        s.abstracted_count = #{length(prunable)},
        s.label_summary = '#{escape_cypher(Enum.join(label_summary, ","))}',
        s.status = 'abstracted'
    WITH s
    MATCH (n)
    WHERE id(n) IN [#{Enum.join(node_ids, ",")}]
    MERGE (s)-[r:ABSTRACTS]->(n)
    SET r.created_at = '#{escape_cypher(created_at)}',
        r.kind = 'sleep_cycle_abstraction'
    RETURN s.id AS supernode_id, s.abstracted_count AS abstracted_count
    """

    case native_module.memgraph_query(query) do
      {:ok, _rows} ->
        {:ok,
         %{
           supernode_count: 1,
           abstracted_count: length(prunable),
           abstraction_ids: [run_id]
         }}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:invalid_abstraction_result, other}}
    end
  end

  defp mark_pruned_candidates(_native_module, [], _cycle_started_at), do: {:ok, 0}
  defp mark_pruned_candidates(native_module, prunable_candidates, cycle_started_at) do
    internal_ids = Enum.map(prunable_candidates, & &1.internal_id)
    recorded_at = DateTime.to_iso8601(cycle_started_at)

    query =
      case internal_ids do
        [] ->
          """
          MATCH (n)
          WHERE n.vfe IS NOT NULL
          SET n.archived = true,
              n.sleep_cycle_status = 'pruned',
              n.pruned_reason = 'high_vfe',
              n.last_sleep_cycle_at = '#{escape_cypher(recorded_at)}',
              n.retained_in_archive = true
          RETURN count(n) AS pruned_count
          """

        ids ->
          """
          MATCH (n)
          WHERE id(n) IN [#{Enum.join(ids, ",")}]
          SET n.archived = true,
              n.sleep_cycle_status = 'pruned',
              n.pruned_reason = 'high_vfe',
              n.last_sleep_cycle_at = '#{escape_cypher(recorded_at)}',
              n.retained_in_archive = true
          RETURN count(n) AS pruned_count
          """
      end

    case native_module.memgraph_query(query) do
      {:ok, [%{"pruned_count" => count} | _]} when is_integer(count) -> {:ok, count}
      {:ok, [%{"pruned_count" => count} | _]} when is_float(count) -> {:ok, trunc(count)}
      {:ok, _rows} -> {:ok, length(prunable_candidates)}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_prune_result, other}}
    end
  end

  defp normalize_sleep_candidate(%{"internal_id" => internal_id, "labels" => labels, "props" => props})
       when is_integer(internal_id) and is_list(labels) and is_map(props) do
    %{
      internal_id: internal_id,
      labels: Enum.map(labels, &to_string/1),
      props: props
    }
  end

  defp normalize_sleep_candidate(_row), do: nil

  defp candidate_prunable?(candidate) do
    vfe =
      candidate.props
      |> Map.get("vfe", 0.0)
      |> normalize_number()

    vfe > @high_vfe_threshold
  end

  defp normalize_number(value) when is_float(value), do: value
  defp normalize_number(value) when is_integer(value), do: value * 1.0

  defp normalize_number(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> 0.0
    end
  end

  defp normalize_number(_value), do: 0.0

  defp sleep_supernode_id(cycle_started_at) do
    "sleep_supernode:" <> DateTime.to_iso8601(cycle_started_at)
  end

  defp escape_cypher(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  defp escape_cypher(value), do: value |> to_string() |> escape_cypher()
end
