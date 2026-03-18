defmodule Core.EpigeneticSupervisionTest do
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
    
    # Cleanup PG groups - ignore errors if process is not in group
    try do
      :pg.leave(:motor, self())
      :pg.leave(:sensory, self())
      :pg.leave(:orchestrator, self())
    rescue
      _ -> :ok
    catch
      _ -> :ok
    end
    
    # Ensure supervisor is clean
    if pid = Process.whereis(EpigeneticSupervisor) do
      for {_, child_pid, _, _} <- DynamicSupervisor.which_children(pid) do
        DynamicSupervisor.terminate_child(pid, child_pid)
      end
    end

    if Process.whereis(Core.Supervisor) do
      Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
      Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end

    {:ok, fake_daemon} = FakeMetabolicDaemon.start_link([])

    on_exit(fn ->
      if Process.alive?(fake_daemon), do: GenServer.stop(fake_daemon)

      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, {Core.MetabolicDaemon, []})
      end
    end)

    :ok
  end

  test "differentiation as motor cell" do
    dna_path = Path.expand("../../priv/dna/motor_cell.yml")
    {:ok, pid} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    # Verify process group membership
    assert pid in :pg.get_members(:motor)
    
    # Verify status
    assert GenServer.call(pid, :get_status) == :active

    # Verify shared and structured routing topics
    assert pid in :pg.get_members(:stem_cell)
    assert pid in :pg.get_members({:cell_role, :motor})
    assert {:ok, discovered_pid} = EpigeneticSupervisor.discover_cell(:motor)
    assert discovered_pid == pid
    
    # Verify synonyms (motor cell DNA has 1 synapse configured in spec)
    # Plus the default pain receptor synapse = 2
    assert GenServer.call(pid, :get_synapse_count) == 2
  end

  test "differentiation as sensory cell" do
    dna_path = Path.expand("../../priv/dna/sensory_cell.yml")
    {:ok, pid} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    assert pid in :pg.get_members(:sensory)
    # sensory_cell.yml has 1 synapse (pub), plus default pain = 2
    assert GenServer.call(pid, :get_synapse_count) == 2
  end

  test "differentiation as orchestrator cell" do
    dna_path = Path.expand("../../priv/dna/orchestrator_cell.yml")
    {:ok, pid} = EpigeneticSupervisor.spawn_cell(dna_path)
    
    assert pid in :pg.get_members(:orchestrator)
  end

  test "role discovery excludes the requesting cell when peers exist" do
    dna_path = Path.expand("../../priv/dna/motor_cell.yml")
    {:ok, pid1} = EpigeneticSupervisor.spawn_cell(dna_path)
    {:ok, pid2} = EpigeneticSupervisor.spawn_cell(dna_path)

    assert Enum.sort(EpigeneticSupervisor.members_for_role(:motor)) == Enum.sort([pid1, pid2])
    assert {:ok, discovered_pid} = EpigeneticSupervisor.discover_cell(:motor, exclude: pid1)
    assert discovered_pid == pid2
  end

  test "refusal to spawn under high metabolic pressure" do
    GenServer.stop(Process.whereis(Core.MetabolicDaemon))
    {:ok, pid} = GenServer.start_link(FakeMetabolicDaemon, :high, name: Core.MetabolicDaemon)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    assert {:error, :metabolic_starvation} = EpigeneticSupervisor.spawn_cell()
  end
end
