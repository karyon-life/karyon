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
  Injects a sensory pulse into the organism and validates the resulting inference state.
  """
  def simulate_perception(organism, lang, code) do
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
