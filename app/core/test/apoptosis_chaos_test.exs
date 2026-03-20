defmodule Core.ApoptosisChaosTest do
  use ExUnit.Case, async: false
  require Logger

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, :low, name: Core.MetabolicDaemon)
    end

    def init(pressure), do: {:ok, pressure}
    def handle_call(:get_pressure, _from, pressure), do: {:reply, pressure, pressure}
    def handle_call(:get_policy, _from, pressure), do: {:reply, Core.MetabolismPolicy.build_policy(pressure), pressure}
  end

  setup do
    Application.ensure_all_started(:core)

    if Process.whereis(Core.Supervisor) do
      Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
      Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end

    {:ok, fake_daemon} = FakeMetabolicDaemon.start_link([])

    on_exit(fn ->
      safe_stop(fake_daemon)

      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, {Core.MetabolicDaemon, []})
      end
    end)

    :ok
  end

  test "resilience under high cell churn" do
    # 1. Spawn a baseline cluster
    dna_path = "/tmp/apoptosis_chaos_motor_#{System.unique_integer([:positive])}.yml"

    File.write!(dna_path, """
    cell_type: motor
    subscriptions:
      - metabolic.spike
    synapses: []
    allowed_actions: []
    """)

    on_exit(fn -> File.rm(dna_path) end)
    
    cells = Enum.map(1..3, fn _ ->
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
    Logger.info("[Chaos] Survivors: #{length(survivors)}/3")
    
    # Spawn replacements
    for _ <- 1..(3 - length(survivors)) do
      assert {:ok, _pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
    end

    # 4. Final check: supervisor is healthy
    assert Process.alive?(Process.whereis(Core.EpigeneticSupervisor))
  end

  test "metabolic-driven pruning of speculative swarms" do
    # 1. Spawn a large swarm of speculative cells (no actions)
    dna_path = "/tmp/apoptosis_chaos_speculative_#{System.unique_integer([:positive])}.yml"

    File.write!(dna_path, """
    cell_type: speculative
    subscriptions:
      - metabolic.spike
    synapses: []
    allowed_actions: []
    utility_threshold: 0.1
    """)

    on_exit(fn -> File.rm(dna_path) end)

    # For CI, we use a smaller count but enough to verify logic
    count = 3
    
    cells = Enum.map(1..count, fn _ ->
      {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
      pid
    end)
    
    initial_count = length(Enum.filter(cells, &Process.alive?/1))
    assert initial_count == count

    # 2. Inject :medium metabolic pressure
    # Speculative cells should undergo apoptosis
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: 0.6, source: "operator_induced"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    
    # Broadcast to all cells via the endocrine topic
    # In this test we send it directly to simulate a broadcast
    refs =
      Enum.map(cells, fn pid ->
        ref = Process.monitor(pid)
        send(pid, {:msg, %{topic: "metabolic.spike", body: payload}})
        {pid, ref}
      end)

    Enum.each(refs, fn {pid, ref} ->
      assert_receive {:DOWN, ^ref, :process, ^pid, :metabolic_pruning}, 5_000
    end)

    survivors = Enum.filter(cells, &Process.alive?/1)
    Logger.info("[MetabolicPruning] Survivors: #{length(survivors)}/#{count}")
    assert survivors == []
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
    
    assert latency < 20_000
  end

  defp safe_stop(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :ok
      end
    else
      :ok
    end
  end
end
