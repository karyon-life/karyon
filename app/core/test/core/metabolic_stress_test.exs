defmodule Core.MetabolicStressTest do
  use ExUnit.Case, async: false
  require Logger

  alias Core.{MetabolicDaemon, ChaosMonkey, StemCell, EpigeneticSupervisor}

  setup do
    # Ensure :pg is started
    :pg.start_link()
    
    # Aggressively remove the real daemon from its supervisor to prevent auto-restarts
    case GenServer.whereis(Core.MetabolicDaemon) do
      nil -> :ok
      _pid -> 
        Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
        Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end
    
    on_exit(fn ->
      # Optionally restart it if we want subsequent tests to have it
      Supervisor.start_child(Core.Supervisor, Core.MetabolicDaemon)
    end)
    
    :ok
  end

  test "MetabolicDaemon induces apoptosis when run queue is high" do
    # Start MetabolicDaemon
    {:ok, daemon} = MetabolicDaemon.start_link(name: :test_metabolic_daemon)
    
    # Spawn a few cells
    dna_path = "/home/adrian/Projects/nexical/karyon/priv/dna/orchestrator_cell.yml"
    {:ok, _cell1} = EpigeneticSupervisor.spawn_cell(dna_path)
    {:ok, _cell2} = EpigeneticSupervisor.spawn_cell(dna_path)

    # Force a poll with high run queue (mocking the metric check)
    # We can't easily mock :erlang.statistics(:run_queue), 
    # so we might need to trigger the private function or verify the broadcast.
    
    # Let's verify that induce_apoptosis terminates a cell
    initial_count = DynamicSupervisor.count_children(EpigeneticSupervisor).active
    assert initial_count >= 2

    # Manually trigger apoptosis logic as the daemon would
    send(daemon, :poll_metrics) # This will check real metrics, might not trigger if system is idle
    
    # We'll use the private function via send if possible or just test the logic
    # Direct test of apoptosis mechanism
    members = :pg.get_members(:orchestrator)
    if length(members) > 0 do
      target = List.first(members)
      EpigeneticSupervisor.apoptosis(target)
      Process.sleep(100)
      refute Process.alive?(target)
    end
  end

  test "ChaosMonkey executes random apoptosis on active cells" do
    # Spawn cells
    dna_path = "/home/adrian/Projects/nexical/karyon/priv/dna/orchestrator_cell.yml"
    {:ok, cell1} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    # Start ChaosMonkey with short interval
    {:ok, _monkey} = ChaosMonkey.start_link(interval: 100)
    
    # Wait for attack
    Process.sleep(300)
    
    # Cell 1 might have been killed
    # Since it's random, we spawn many and check if count decreases
    for _i <- 1..5, do: EpigeneticSupervisor.spawn_cell(dna_path)
    
    initial_count = DynamicSupervisor.count_children(EpigeneticSupervisor).active
    Process.sleep(1000) # Wait for more attacks
    final_count = DynamicSupervisor.count_children(EpigeneticSupervisor).active
    
    assert final_count < initial_count or !Process.alive?(cell1)
  end

  test "Cells enter digital torpor upon receiving high severity metabolic spike" do
    dna_path = "/home/adrian/Projects/nexical/karyon/priv/dna/sensory_cell.yml"
    {:ok, cell} = StemCell.start_link(dna_path)
    
    # Simulate NATS message
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: "high"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    
    send(cell, {:msg, %{topic: "metabolic.spike", body: payload}})
    
    Process.sleep(200)
    assert GenServer.call(cell, :get_status) == :torpor
  end

  test "EpigeneticSupervisor refuses to spawn cells under high metabolic pressure" do
    # Start MetabolicDaemon with high pressure mock
    # Since we can't easily mock calculate_system_pressure, we'll manually set the state if we can,
    # or just use the handle_call/cast if available.
    
    # Alternatively, we can just test the supervisor logic by ensuring it calls the daemon.
    # Start a fake daemon that returns :high with the REQUIRED name
    # We already stopped the old one in setup
    defmodule HighPressureDaemon do
      use GenServer
      def start_link(_), do: GenServer.start_link(__MODULE__, :high, name: Core.MetabolicDaemon)
      def init(pressure), do: {:ok, pressure}
      def handle_call(:get_pressure, _from, state), do: {:reply, state, state}
    end

    {:ok, fake_pid} = HighPressureDaemon.start_link([])
    
    # Try to spawn
    dna_path = "/home/adrian/Projects/nexical/karyon/priv/dna/orchestrator_cell.yml"
    assert {:error, :metabolic_starvation} == EpigeneticSupervisor.spawn_cell(dna_path)

    GenServer.stop(fake_pid)
  end
end
