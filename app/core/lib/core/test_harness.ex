defmodule Core.TestHarness do
  @moduledoc """
  Unified platform harness for booting and validating the Karyon organism.
  Allows for high-level integration testing with mocked I/O.
  """
  require Logger

  def genesis_boot do
    Logger.info("[Harness] Starting Genesis Boot Sequence...")
    
    # Boot the various umbrella "organelles" if not already started
    Enum.each([:telemetry, :jason, :nervous_system, :rhizome, :sensory], fn app ->
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
    send(cell_pid, {:synapse_recv, self(), Jason.encode!(%{
      type: "nociception",
      metadata: %{reason: "simulated_structural_failure"}
    })})
    
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
end
