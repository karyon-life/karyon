defmodule Core.ApoptosisChaosTest do
  use ExUnit.Case, async: false
  require Logger

  setup do
    # Application supervisor already starts this
    :ok
  end

  test "resilience under high cell churn" do
    # 1. Spawn a baseline cluster
    dna_path = Path.expand("../config/genetics/base_stem_cell.yml", __DIR__)
    
    cells = Enum.map(1..20, fn _ ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)

    # 2. Chaos Loop: Kill 10% of cells every 100ms for 1 second
    # Note: Since they are currently :temporary, they won't restart automatically!
    # We will verify that we can still spawn MORE cells and the supervisor doesn't crash.
    
    Enum.each(1..10, fn _ ->
      to_kill = Enum.take_random(cells, 2)
      Enum.each(to_kill, fn pid ->
        if Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end)
      Process.sleep(100)
    end)

    # 3. Verify survivors and spawn new ones
    survivors = Enum.filter(cells, &Process.alive?/1)
    Logger.info("[Chaos] Survivors: #{length(survivors)}/20")
    
    # Spawn replacements
    for _ <- 1..(20 - length(survivors)) do
      assert {:ok, _pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
    end

    # 4. Final check: supervisor is healthy
    assert Process.alive?(Process.whereis(Core.EpigeneticSupervisor))
  end

  test "metabolic-driven pruning of speculative swarms" do
    # 1. Spawn a large swarm of speculative cells (no actions)
    dna_path = Path.expand("../../priv/dna/speculative_cell.yml", __DIR__)
    # For CI, we use a smaller count but enough to verify logic
    count = 50
    
    cells = Enum.map(1..count, fn _ ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)
    
    initial_count = length(Enum.filter(cells, &Process.alive?/1))
    assert initial_count == count

    # 2. Inject :medium metabolic pressure
    # Speculative cells should undergo apoptosis
    spike = NervousSystem.Protos.MetabolicSpike.new(severity: "medium")
    payload = NervousSystem.Protos.MetabolicSpike.encode(spike)
    
    # Broadcast to all cells via the endocrine टॉपिक
    # In this test we send it directly to simulate a broadcast
    Enum.each(cells, fn pid -> send(pid, {:msg, "metabolic.spike", payload}) end)
    
    # 3. Wait for pruning
    Process.sleep(500)
    
    # 4. Verify population reduction
    survivors = Enum.filter(cells, &Process.alive?/1)
    Logger.info("[MetabolicPruning] Survivors: #{length(survivors)}/#{count}")
    
    assert length(survivors) < initial_count
    # Since they are all speculative, they should all be dead or dying
    assert length(survivors) == 0
  end

  test "Synaptic latency verification (Tier 2 Performance)" do
    {:ok, pull} = NervousSystem.Synapse.start_link(type: :pull)
    {:ok, port} = GenServer.call(pull, :get_port)
    {:ok, push} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)
    
    Process.sleep(100)
    
    start_time = System.monotonic_time(:microsecond)
    NervousSystem.Synapse.send_signal(push, "ping")
    
    # Wait for recv link
    assert_receive {:synapse_recv, ^pull, "ping"}, 500
    
    end_time = System.monotonic_time(:microsecond)
    latency = end_time - start_time
    Logger.info("[Latency] Synaptic delivery: #{latency}us")
    
    assert latency < 5000 # Under 5ms for local socket
  end
end
