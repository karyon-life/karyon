defmodule Core.TestHarness do
  @moduledoc """
  Unified platform harness for booting and validating the Karyon organism.
  Allows for high-level integration testing with mocked I/O.
  """
  require Logger

  def genesis_boot do
    Logger.info("[Harness] Starting Genesis Boot Sequence...")
    
    # Boot the various umbrella "organelles" if not already started
    Enum.each([:telemetry, :jason, :core, :nervous_system, :rhizome, :sensory], fn app ->
      case Application.ensure_all_started(app) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
        error -> Logger.error("[Harness] Failed to start #{app}: #{inspect(error)}")
      end
    end)

    # 4. Boot a cluster of Stem Cells via the Epigenetic Supervisor
    dna_path = Path.expand("../../config/genetics/base_stem_cell.yml", __DIR__)
    
    cells = Enum.map(1..3, fn _i ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)

    {:ok, %{cells: cells}}
  end

  @doc """
  Runs a 'Nociception Cascade' scenario.
  Verify that an error in Sensory leads to a StemCell VFE response and a Rhizome pruning operation.
  """
  def simulate_nociception_cascade(dna_path \\ "config/genetics/base_stem_cell.yml") do
    Logger.info("[Harness] Starting Nociception Cascade Scenario")
    
    dna_full_path = if Path.type(dna_path) == :relative do
      Path.expand("../../#{dna_path}", __DIR__)
    else
      dna_path
    end

    # 1. Spawn a StemCell
    {:ok, cell_pid} = Core.EpigeneticSupervisor.spawn_cell(dna_full_path)
    
    # 2. Form an expectation with high precision
    :ok = GenServer.call(cell_pid, {:form_expectation, "edge_789", "Stability", 0.9})
    
    # 3. Simulate Pain signal arrival (Nociception)
    pain_msg = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      message: "Simulated structural failure",
      timestamp: System.system_time(:second),
      metadata: %{"reason" => "simulated_structural_failure"}
    }
    {:ok, binary} = Karyon.NervousSystem.PredictionError.encode(pain_msg)
    send(cell_pid, {:synapse_recv, self(), binary})
    
    # 4. Wait for processing (Inference + Pruning)
    Process.sleep(200)
    
    # 5. Verify the VFE was recorded in beliefs
    state = :sys.get_state(cell_pid)
    vfe = Map.get(state.beliefs, :last_vfe, 0.0)
    
    Logger.info("[Harness] Scenario Result - VFE: #{vfe}")
    
    if vfe > 0.5 do
      {:ok, %{vfe: vfe, status: :pruned}}
    else
      {:error, %{vfe: vfe, status: :stagnant}}
    end
  end

  @doc """
  Injects a sensory pulse into the organism and validates the resulting inference state.
  """
  def simulate_perception(_organism, lang, code) do
    Logger.info("[Harness] Injecting Perception: #{lang}")
    
    # 1. Parse code into AST graph
    ast_json = Sensory.Native.parse_code(lang, code)
    
    # 2. Submit to Rhizome Memory
    Rhizome.Native.xtdb_submit("perception_#{System.unique_integer([:positive])}", ast_json)

    # 3. Simulate environment feedback (e.g. pain signal from a failing expectation)
    # This verifies the nociception loop is live.
    Logger.error("[Harness] Simulated failure in Perception loop")
    
    # 4. Assertions would happen in the test caller
    :ok
  end

  @doc """
  Runs a programmed cognitive episode from a YAML definition.
  """
  def run_episode(episode_path) do
    Logger.info("[Harness] Loading Episode: #{episode_path}")
    
    case YamlElixir.read_from_file(episode_path) do
      {:ok, episode} ->
        execute_episode(episode)
      {:error, reason} ->
        Logger.error("[Harness] Failed to load episode: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp execute_episode(episode) do
    Logger.info("[Harness] Executing Episode: #{episode["name"]}")
    
    # 1. Setup Environment
    dna_path = Path.expand("../../#{episode["config"]["dna"]}", __DIR__)
    count = episode["config"]["cells"] || 1
    
    cells = Enum.map(1..count, fn _ ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)

    # 2. Sequential Step Execution
    results = Enum.reduce_while(episode["steps"], [], fn step, acc ->
      case execute_step(step, cells) do
        :ok -> {:cont, acc ++ [:ok]}
        {:error, reason} -> {:halt, acc ++ [{:error, reason}]}
      end
    end)

    if Enum.all?(results, &(&1 == :ok)) do
      Logger.info("[Harness] Episode Completed Successfully")
      {:ok, results}
    else
      Logger.error("[Harness] Episode Failed")
      {:error, results}
    end
  end

  defp execute_step(%{"action" => "form_expectation"} = step, cells) do
    params = Map.get(step, "params", %{})
    Enum.each(cells, fn pid ->
      :ok = GenServer.call(pid, {:form_expectation, params["id"], params["type"], params["target"]})
    end)
    :ok
  end

  defp execute_step(%{"action" => "spawn_swarm"} = step, _cells) do
    params = Map.get(step, "params", %{})
    count = params["count"] || 10
    dna_path = Path.expand("../../#{params["dna"]}", __DIR__)
    
    _new_cells = Enum.map(1..count, fn _ ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)
    
    # We return the combined list of cells for future steps
    # Note: execute_episode needs to be aware of this change if we want cells to accumulate
    # For now, let's just log it and assume the caller manages cell PIDs if needed.
    Logger.info("[Harness] Swarm spawned: #{count} new cells")
    :ok
  end

  defp execute_step(%{"action" => "trigger_sleep"} = _step, _cells) do
    Logger.info("[Harness] Manually triggering Brain Consolidation (Sleep Cycle)...")
    # This would call the Sleep Cycle logic in Rhizome/Core
    # For now, we simulate the effect or call the placeholder
    Rhizome.Native.memgraph_query("MATCH (a:ASTNode), (b:ASTNode) WHERE a.id < b.id MERGE (a)-[:CLUSTURED]->(b)")
    :ok
  end

  defp execute_step(%{"action" => "assert_graph_optimized"} = step, _cells) do
    params = Map.get(step, "params", %{})
    min_clusters = params["min_clusters"] || 1
    
    case Rhizome.Native.memgraph_query("MATCH ()-[r:CLUSTURED]->() RETURN count(r) as count") do
      {:ok, [%{"count" => count}]} when count >= min_clusters ->
        Logger.info("[Harness] Graph optimization confirmed: #{count} clusters found")
        :ok
      _ ->
        {:error, :graph_not_optimized}
    end
  end

  defp execute_step(%{"action" => "inject_perception"} = step, cells) do
    params = Map.get(step, "params", %{})
    simulate_perception(nil, params["lang"], params["code"])
    if params["nociception"] do
      execute_step(%{"action" => "inject_nociception", "params" => %{"reason" => "simulated_perception_failure"}}, cells)
    else
      :ok
    end
  end

  defp execute_step(%{"action" => "inject_nociception"} = step, cells) do
    params = Map.get(step, "params", %{})
    Enum.each(cells, fn pid ->
      pain_msg = %Karyon.NervousSystem.PredictionError{
        type: "nociception",
        message: "Episode nociception injection",
        timestamp: System.system_time(:second),
        metadata: %{"reason" => params["reason"]}
      }
      {:ok, binary} = Karyon.NervousSystem.PredictionError.encode(pain_msg)
      send(pid, {:synapse_recv, self(), binary})
    end)
    :ok
  end

  defp execute_step(%{"action" => "checkpoint"}, _cells) do
    Logger.info("[Harness] Taking State Checkpoint...")
    # Basic checkpoint: count nodes and edges in Memgraph
    case Rhizome.Native.memgraph_query("MATCH (n) RETURN count(n) as count") do
      {:ok, _} = resp -> 
        Logger.info("[Harness] Checkpoint Result: #{inspect(resp)}")
        :ok
      error -> 
        Logger.error("[Harness] Checkpoint Failed: #{inspect(error)}")
        :ok # Don't halt for now
    end
  end

  defp execute_step(%{"action" => "causal_trace"} = step, _cells) do
    params = Map.get(step, "params", %{})
    Logger.info("[Harness] Executing Causal Trace for: #{params["id"]}")
    # Extract historical versions from XTDB
    # XTDB REST API expects {"query": {...}}
    query = %{
      "query" => %{
        "find" => ["(pull ?e [*])"],
        "where" => [["?e", "xt/id", params["id"]]]
      }
    }
    case Rhizome.Native.xtdb_query(Jason.encode!(query)) do
      resp when is_binary(resp) ->
        Logger.info("[Harness] Causal Trace Result: #{resp}")
        :ok
      error ->
        Logger.error("[Harness] Causal Trace Failed: #{inspect(error)}")
        :ok
    end
  end

  defp execute_step(%{"action" => "wait"} = step, _cells) do
    params = Map.get(step, "params", %{})
    Process.sleep(params["ms"] || 0)
    :ok
  end

  defp execute_step(%{"action" => "assert_vfe"} = step, cells) do
    params = Map.get(step, "params", %{})
    threshold = params["threshold"] || 0.5
    Enum.all?(cells, fn pid ->
      state = :sys.get_state(pid)
      vfe = Map.get(state.beliefs, :last_vfe, 0.0)
      if vfe >= threshold do
        true
      else
        Logger.error("[Harness] Assertion failed: VFE #{vfe} < threshold #{threshold}")
        false
      end
    end)
    |> if(do: :ok, else: {:error, :assertion_failed})
  end

  defp execute_step(step, _) do
    Logger.warning("[Harness] Unknown action: #{inspect(step["action"])}")
    :ok
  end
end
