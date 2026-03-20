defmodule Core.PlatformIntegrationTest do
  use ExUnit.Case, async: false # Integration tests usually aren't async due to global shared resources
  @moduletag :external
  require Logger

  alias NervousSystem.Endocrine

  setup_all do
    case Core.ServiceHealth.ensure_ready([:memgraph, :xtdb, :nats]) do
      :ok ->
        {:ok, organism} = Core.TestHarness.genesis_boot()
        {:ok, organism: organism}

      {:error, {:dependencies_unready, blocked, report}} ->
        {:ok, skip: "Platform integration dependencies unavailable: #{inspect(blocked)} #{inspect(report)}"}
    end
  end

  test "End-to-end flow: Sensory -> Orchestrator -> Motor -> Archive", %{organism: _organism} do
    code = "hellohello"
    dna_path = Path.expand("../config/genetics/base_stem_cell.yml", __DIR__)

    {:ok, gnat_pid} = Endocrine.start_connection("platform_integration")

    if is_nil(Process.whereis(:endocrine_gnat)) do
      Process.register(gnat_pid, :endocrine_gnat)
    end

    on_exit(fn ->
      if Process.whereis(:endocrine_gnat) == gnat_pid, do: Process.unregister(:endocrine_gnat)
      if Process.alive?(gnat_pid), do: GenServer.stop(gnat_pid)
    end)

    # 1. Ingest raw bytes through the sensory layer into Memgraph.
    assert {:ok, %{pooled_sequences: sequences}} = Sensory.ingest_bytes(code)
    assert sequences != []

    # 2. Verify sensory output persisted in the graph layer.
    assert {:ok, [%{"count" => count}]} =
             Rhizome.Native.memgraph_query("MATCH (n:PooledSequence) RETURN count(n) AS count")

    assert count >= 1

    # 3. Bridge graph state into XTDB v2 and seed beliefs for a new cell lineage.
    assert {:ok, %{message: msg}} = Rhizome.Native.bridge_to_xtdb()
    assert String.contains?(msg, "bridged")

    assert {:ok, %{raw: _}} =
             Rhizome.Native.xtdb_submit(dna_path, %{
               "beliefs" => %{"source" => "platform_integration"}
             })

    # 4. Spawn a new cell and verify it hydrates beliefs from XTDB.
    {:ok, cell_pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
    state = :sys.get_state(cell_pid)
    assert state.beliefs["source"] == "platform_integration"

    # 5. Drive a real endocrine signal through the new cell and verify the response.
    spike = %Karyon.NervousSystem.MetabolicSpike{
      severity: 1.0,
      source: "operator_induced",
      metric_type: "platform_integration"
    }

    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)

    Process.sleep(200)
    :ok = Endocrine.publish_gradient(gnat_pid, "metabolic.spike", payload)
    Process.sleep(300)

    assert GenServer.call(cell_pid, :get_status) == :torpor
  end

  @tag :chaos
  test "organism survives random component termination (Chaos engineering)", %{organism: _organism} do
    # 1. Identify critical platform processes
    critical_apps = [:rhizome, :sensory, :nervous_system]
    
    # 2. Kill one random app's supervisor
    target_app = Enum.random(critical_apps)
    Logger.warning("[PlatformTest] CHAOS: Terminating #{target_app} to test supervision tree...")
    
    Application.stop(target_app)
    
    # 3. Wait for recovery (OTP supervision)
    Process.sleep(500)
    
    # 4. Attempt a platform action to verify recovery
      case target_app do
      :rhizome ->
        assert {:ok, _} = Rhizome.Native.memgraph_query("MATCH (n) RETURN count(n)")
      :sensory ->
        assert {:ok, _} = Sensory.ingest_bytes("hellohello")
      _ ->
        :ok
    end
    
    # Ensure it's started back for other tests
    Application.ensure_all_started(target_app)
  end
end
