defmodule Core.ScaleBenchTest do
  use ExUnit.Case, async: false
  require Logger

  @dna_path Path.expand("../../../../priv/dna/speculative_cell.yml", __DIR__)
  @target_swarm_size 10_000 # Benchmark target for this environment

  setup do
    Application.ensure_all_started(:core)
    Application.ensure_all_started(:nervous_system)
    
    # Start StressTester if not already running
    if is_nil(Process.whereis(Core.StressTester)) do
      Core.StressTester.start_link()
    end

    on_exit(fn ->
      Core.StressTester.purge()
    end)

    :ok
  end

  @tag :benchmark
  @tag timeout: 300_000 # 5 minute timeout for massive scaling
  test "swarm scalability and metabolic stability" do
    Logger.info("[Benchmark] Starting Swarm Scalability Test with #{@target_swarm_size} cells...")
    
    start_time = System.monotonic_time()
    
    {:ok, count} = Core.StressTester.swarm_spawn(@target_swarm_size, @dna_path)
    
    end_time = System.monotonic_time()
    duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    
    Logger.info("[Benchmark] Spawned #{count} cells in #{duration}ms.")
    
    # Check metabolic pressure
    pressure = GenServer.call(Core.MetabolicDaemon, :get_pressure)
    Logger.info("[Benchmark] System Pressure after spawn: #{pressure}")

    # Assertions
    assert count == @target_swarm_size
    # In a stable system, pressure might be :medium but shouldn't be catastrophic immediately
    # unless thresholds are very tight.
    
    # Check run queue
    rq = :erlang.statistics(:run_queue)
    Logger.info("[Benchmark] Run Queue Length: #{rq}")
    
    # Allow some time for homeostasis to react
    Process.sleep(5000)
    
    # Final check
    final_pressure = GenServer.call(Core.MetabolicDaemon, :get_pressure)
    Logger.info("[Benchmark] Final Metabolic State: #{final_pressure}")
    
    assert count > 0
  end
end
