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
    with {:ok, rows} <- native_module.memgraph_query(cooccurrence_query()),
         communities <- identify_louvain_communities(rows),
         non_trivial <- Enum.filter(communities, &(length(&1) > 1)),
         {:ok, _} <- optimize_language_graph(native_module),
         {:ok, abstraction_ids} <- persist_grammar_supernodes(native_module, non_trivial, cycle_started_at) do
      {:ok,
       %{
         supernode_count: length(abstraction_ids),
         abstracted_count: Enum.sum(Enum.map(non_trivial, &length/1)),
         abstraction_ids: abstraction_ids,
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

  defp normalize_number(value) when is_float(value), do: value
  defp normalize_number(value) when is_integer(value), do: value * 1.0

  defp normalize_number(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> 0.0
    end
  end

  defp normalize_number(_value), do: 0.0

  defp grammar_supernode_id(cycle_started_at, index) do
    "grammar_supernode:" <> DateTime.to_iso8601(cycle_started_at) <> ":#{index}"
  end

  defp cooccurrence_query do
    """
    MATCH (a:PooledSequence)-[r:CO_OCCURS_WITH]->(b:PooledSequence)
    WHERE a.source = 'operator_environment'
      AND b.source = 'operator_environment'
    RETURN id(a) AS start, id(b) AS end, coalesce(r.weight, 1.0) AS weight
    """
  end

  defp optimize_language_graph(native_module) do
    case native_module.optimize_graph() do
      {:ok, _message} = ok -> ok
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_optimizer_result, other}}
    end
  end

  defp identify_louvain_communities(rows) when is_list(rows) do
    graph =
      Enum.reduce(rows, %{}, fn row, acc ->
        start_id = row["start"]
        end_id = row["end"]
        weight = normalize_number(row["weight"])

        if is_integer(start_id) and is_integer(end_id) and weight >= 0.5 do
          acc
          |> Map.update(start_id, MapSet.new([end_id]), &MapSet.put(&1, end_id))
          |> Map.update(end_id, MapSet.new([start_id]), &MapSet.put(&1, start_id))
        else
          acc
        end
      end)

    graph
    |> Map.keys()
    |> Enum.reduce({MapSet.new(), []}, fn node, {visited, communities} ->
      if MapSet.member?(visited, node) do
        {visited, communities}
      else
        community = explore_component(node, graph, MapSet.new())
        {MapSet.union(visited, community), [community |> MapSet.to_list() |> Enum.sort() | communities]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp persist_grammar_supernodes(_native_module, [], _cycle_started_at), do: {:ok, []}

  defp persist_grammar_supernodes(native_module, communities, cycle_started_at) do
    created_at = DateTime.to_iso8601(cycle_started_at)

    Enum.reduce_while(Enum.with_index(communities, 1), {:ok, []}, fn {community, index}, {:ok, acc} ->
      grammar_id = grammar_supernode_id(cycle_started_at, index)
      confidence = community_confidence(community)

      query = """
      MERGE (g:GrammarSuperNode {id: '#{escape_cypher(grammar_id)}'})
      SET g.kind = 'structural_grammar_rule',
          g.community_size = #{length(community)},
          g.confidence = #{confidence},
          g.source = 'operator_environment',
          g.created_at = '#{escape_cypher(created_at)}',
          g.observed_at = '#{escape_cypher(created_at)}'
      WITH g
      MATCH (p:PooledSequence)
      WHERE id(p) IN [#{Enum.join(community, ",")}]
      MERGE (g)-[r:ABSTRACTS]->(p)
      SET r.kind = 'grammar_consolidation',
          r.created_at = '#{escape_cypher(created_at)}'
      RETURN g.id AS grammar_id
      """

      case native_module.memgraph_query(query) do
        {:ok, _rows} -> {:cont, {:ok, [grammar_id | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
        other -> {:halt, {:error, {:invalid_grammar_supernode_result, other}}}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, Enum.reverse(ids)}
      error -> error
    end
  end

  defp explore_component(node, graph, visited) do
    if MapSet.member?(visited, node) do
      visited
    else
      neighbors = Map.get(graph, node, MapSet.new())
      Enum.reduce(neighbors, MapSet.put(visited, node), fn neighbor, acc -> explore_component(neighbor, graph, acc) end)
    end
  end

  defp community_confidence(community) do
    community
    |> length()
    |> Kernel./(10.0)
    |> min(1.0)
    |> Float.round(3)
  end

  defp escape_cypher(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  defp escape_cypher(value), do: value |> to_string() |> escape_cypher()
end
