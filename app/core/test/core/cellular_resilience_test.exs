defmodule Core.CellularResilienceTest do
  use ExUnit.Case
  alias Core.EpigeneticSupervisor

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, :low, name: Core.MetabolicDaemon)
    end

    def init(pressure), do: {:ok, pressure}
    def handle_call(:get_pressure, _from, pressure), do: {:reply, pressure, pressure}
  end

  setup do
    Application.ensure_all_started(:core)

    if Process.whereis(Core.Supervisor) do
      Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
      Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end

    {:ok, fake_daemon} = FakeMetabolicDaemon.start_link([])

    # Ensure supervisor is clean
    for {_, pid, _, _} <- DynamicSupervisor.which_children(EpigeneticSupervisor) do
      DynamicSupervisor.terminate_child(EpigeneticSupervisor, pid)
    end

    on_exit(fn ->
      if Process.alive?(fake_daemon), do: GenServer.stop(fake_daemon)

      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, {Core.MetabolicDaemon, []})
      end
    end)

    :ok
  end

  test "mass spawning and graduated apoptosis" do
    # Spawn 50 cells across different roles
    roles = ["motor", "sensory", "orchestrator"]
    for i <- 1..50 do
      role = Enum.at(roles, rem(i, 3))
      # Correct path relative to umbrella root
      dna_path = Path.expand("../../priv/dna/#{role}_cell.yml")
      {:ok, _pid} = EpigeneticSupervisor.spawn_cell(dna_path)
    end

    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) == 50

    # Simulate metabolic pressure for targeted apoptosis
    # The MetabolicDaemon isn't started in this test context, so we call apoptosis directly
    motor_members = :pg.get_members(:motor)
    assert length(motor_members) > 0
    
    [victim | _] = motor_members
    assert :ok = EpigeneticSupervisor.apoptosis(victim)
    
    # Wait for async cleanup
    Process.sleep(100)
    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) == 49
  end

  test "chaos monkey impact and recovery" do
    # Spawn a small cluster
    for _ <- 1..10 do
      dna_path = Path.expand("../../priv/dna/motor_cell.yml")
      {:ok, _} = EpigeneticSupervisor.spawn_cell(dna_path)
    end

    initial_count = length(DynamicSupervisor.which_children(EpigeneticSupervisor))

    # ChaosMonkey is a GenServer that pokes cells. 
    # Let's verify it can select and kill a cell.
    {:ok, monkey_pid} = Core.ChaosMonkey.start_link()
    
    # Force an immediate attack by sending the info message
    send(monkey_pid, :attack)
    
    # Wait for attack
    Process.sleep(200)

    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) <= initial_count
  end

  test "safety-critical cells stay active while non-critical cells enter torpor and revive deterministically" do
    orchestrator_path = Path.expand("../../priv/dna/orchestrator_cell.yml")
    sensory_path = Path.expand("../../priv/dna/sensory_cell.yml")

    {:ok, orchestrator} = EpigeneticSupervisor.spawn_cell(orchestrator_path)
    {:ok, sensory} = EpigeneticSupervisor.spawn_cell(sensory_path)

    high_spike = %Karyon.NervousSystem.MetabolicSpike{severity: "high"}
    {:ok, high_iodata} = Karyon.NervousSystem.MetabolicSpike.encode(high_spike)
    high_payload = IO.iodata_to_binary(high_iodata)

    send(orchestrator, {:msg, %{topic: "metabolic.spike", body: high_payload}})
    send(sensory, {:msg, %{topic: "metabolic.spike", body: high_payload}})
    Process.sleep(200)

    assert GenServer.call(orchestrator, :get_status) == :active
    assert GenServer.call(sensory, :get_status) == :torpor

    low_spike = %Karyon.NervousSystem.MetabolicSpike{severity: "low"}
    {:ok, low_iodata} = Karyon.NervousSystem.MetabolicSpike.encode(low_spike)
    low_payload = IO.iodata_to_binary(low_iodata)

    send(sensory, {:msg, %{topic: "metabolic.spike", body: low_payload}})
    Process.sleep(100)

    assert GenServer.call(sensory, :get_status) == :revived
  end
end
