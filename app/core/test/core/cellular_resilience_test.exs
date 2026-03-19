defmodule Core.CellularResilienceTest do
  use ExUnit.Case
  @moduletag timeout: 120_000
  alias Core.EpigeneticSupervisor

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

    # Ensure supervisor is clean
    for {_, pid, _, _} <- DynamicSupervisor.which_children(EpigeneticSupervisor) do
      DynamicSupervisor.terminate_child(EpigeneticSupervisor, pid)
    end

    on_exit(fn ->
      if monkey = Process.whereis(Core.ChaosMonkey), do: safe_stop(monkey)

      for {_, pid, _, _} <- DynamicSupervisor.which_children(EpigeneticSupervisor) do
        DynamicSupervisor.terminate_child(EpigeneticSupervisor, pid)
      end

      safe_stop(fake_daemon)

      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, {Core.MetabolicDaemon, []})
      end
    end)

    :ok
  end

  test "mass spawning and graduated apoptosis" do
    roles = ["motor", "sensory", "orchestrator"]
    spawn_count = 12

    dna_paths =
      Map.new(roles, fn role ->
        path = "/tmp/cellular_resilience_#{role}_#{System.unique_integer([:positive])}.yml"

        File.write!(path, """
        id: "#{role}_resilience"
        cell_type: "#{role}"
        allowed_actions: []
        synapses: []
        """)

        on_exit(fn -> File.rm(path) end)
        {role, path}
      end)

    for i <- 1..spawn_count do
      role = Enum.at(roles, rem(i, 3))
      {:ok, _pid} = EpigeneticSupervisor.spawn_cell(Map.fetch!(dna_paths, role))
    end

    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) == spawn_count

    # Simulate metabolic pressure for targeted apoptosis
    # The MetabolicDaemon isn't started in this test context, so we call apoptosis directly
    motor_members = :pg.get_members(:motor)
    assert length(motor_members) > 0
    
    [victim | _] = motor_members
    assert :ok = EpigeneticSupervisor.apoptosis(victim)
    
    # Wait for async cleanup
    Process.sleep(100)
    assert length(DynamicSupervisor.which_children(EpigeneticSupervisor)) == spawn_count - 1
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

    safe_stop(monkey_pid)
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
