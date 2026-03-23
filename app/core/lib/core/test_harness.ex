defmodule Core.TestHarness do
  @moduledoc """
  Unified platform harness for booting and validating the Karyon organism.
  Allows for high-level integration testing with modernized signaling.
  """
  require Logger

  def genesis_boot do
    Logger.info("[Harness] Starting Genesis Boot Sequence...")
    with :ok <- Core.ServiceHealth.ensure_ready([:memgraph, :xtdb, :nats]) do
      do_genesis_boot()
    end
  end

  defp do_genesis_boot do
    Enum.each([:telemetry, :jason, :core, :nervous_system, :rhizome, :sensory], fn app ->
      case Application.ensure_all_started(app) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
        error -> Logger.error("[Harness] Failed to start #{app}: #{inspect(error)}")
      end
    end)

    dna_path = Path.expand("../../config/genetics/base_stem_cell.yml", __DIR__)
    
    cells = Enum.map(1..3, fn _i ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)

    {:ok, %{cells: cells}}
  end

  def simulate_nociception_cascade(dna_path \\ "config/genetics/base_stem_cell.yml") do
    Logger.info("[Harness] Starting Nociception Cascade Scenario")
    
    dna_full_path = if Path.type(dna_path) == :relative do
      Path.expand("../../#{dna_path}", __DIR__)
    else
      dna_path
    end

    {:ok, cell_pid} = Core.EpigeneticSupervisor.spawn_cell(dna_full_path)
    :ok = GenServer.call(cell_pid, {:form_expectation, "edge_789", "Stability", 0.9})
    
    # Modernized: Broadcast via PubSub instead of direct send
    prediction_error = %{
      id: "test:nociception:#{System.system_time(:millisecond)}",
      type: "nociception",
      message: "Simulated structural failure",
      timestamp: System.system_time(:second),
      metadata: %{"reason" => "simulated_structural_failure"},
      cell_id: "harness",
      source: "harness",
      severity: 1.0
    }
    
    NervousSystem.PubSub.broadcast(:nociception, {:prediction_error, prediction_error})
    
    Process.sleep(200)
    
    state = :sys.get_state(cell_pid)
    vfe = Map.get(state.beliefs, :last_vfe, 0.0)
    
    Logger.info("[Harness] Scenario Result - VFE: #{vfe}")
    
    if vfe > 0.5 do
      {:ok, %{vfe: vfe, status: :pruned}}
    else
      {:error, %{vfe: vfe, status: :stagnant}}
    end
  end

  def simulate_perception(_organism, lang, code) do
    Logger.info("[Harness] Injecting Perception: #{lang}")

    with :ok <- Core.ServiceHealth.ensure_ready([:memgraph, :xtdb]) do
      # Modernized: Call the PeripheralNif directly for BPE compression
      {:ok, tokens} = Sensory.PeripheralNif.compress_stream(self(), code, 0.8, 5)
      
      Rhizome.Native.xtdb_submit(
        "perception_#{System.unique_integer([:positive])}",
        Jason.encode!(%{
          "language" => lang,
          "tokens_count" => length(tokens),
          "timestamp" => System.system_time(:second)
        })
      )

      Logger.error("[Harness] Simulated failure in Perception loop")
      :ok
    end
  end

  def run_episode(episode_path) do
    Logger.info("[Harness] Loading Episode: #{episode_path}")
    case YamlElixir.read_from_file(episode_path) do
      {:ok, episode} -> execute_episode(episode)
      {:error, reason} -> 
        Logger.error("[Harness] Failed to load episode: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp execute_episode(episode) do
    dna_path = Path.expand("../../#{episode["config"]["dna"]}", __DIR__)
    count = episode["config"]["cells"] || 1
    cells = Enum.map(1..count, fn _ ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)

    results = Enum.reduce_while(episode["steps"], [], fn step, acc ->
      case execute_step(step, cells) do
        :ok -> {:cont, acc ++ [:ok]}
        {:error, reason} -> {:halt, acc ++ [{:error, reason}]}
      end
    end)

    if Enum.all?(results, &(&1 == :ok)), do: {:ok, results}, else: {:error, results}
  end

  defp execute_step(%{"action" => "form_expectation"} = step, cells) do
    params = Map.get(step, "params", %{})
    Enum.each(cells, fn pid ->
      :ok = GenServer.call(pid, {:form_expectation, params["id"], params["type"], params["target"]})
    end)
    :ok
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

  defp execute_step(%{"action" => "inject_nociception"} = step, _cells) do
    params = Map.get(step, "params", %{})
    prediction_error = %{
      id: "test:nociception:#{System.system_time(:millisecond)}",
      type: "nociception",
      message: "Episode nociception injection",
      timestamp: System.system_time(:second),
      metadata: %{"reason" => params["reason"]},
      cell_id: "harness",
      source: "harness",
      severity: 1.0
    }
    NervousSystem.PubSub.broadcast(:nociception, {:prediction_error, prediction_error})
    :ok
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
      vfe >= threshold
    end)
    |> if(do: :ok, else: {:error, :assertion_failed})
  end

  defp execute_step(step, _) do
    Logger.warning("[Harness] Unknown action or legacy action skipped: #{inspect(step["action"])}")
    :ok
  end
end
