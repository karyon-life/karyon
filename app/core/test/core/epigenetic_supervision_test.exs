defmodule Core.EpigeneticSupervisionTest do
  use ExUnit.Case
  alias Core.EpigeneticSupervisor

  defmodule MemoryStub do
    def load_cell_state(_lineage_id), do: {:error, :not_found}
    def checkpoint_cell_state(snapshot), do: {:ok, %{id: snapshot["lineage_id"] || "checkpoint"}}
    def submit_prediction_error(_event), do: {:ok, %{id: "prediction_error"}}
    def submit_execution_outcome(_event), do: {:ok, %{id: "execution_outcome"}}

    def submit_differentiation_event(event) do
      if pid = Process.whereis(:epigenetic_supervision_observer) do
        send(pid, {:differentiation_event_persisted, event})
      end

      {:ok, %{id: event["lineage_id"]}}
    end
  end

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

    original_module = Application.get_env(:core, :memory_module)
    Application.put_env(:core, :memory_module, MemoryStub)
    Process.register(self(), :epigenetic_supervision_observer)
    
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
      if Process.whereis(:epigenetic_supervision_observer) == self(), do: Process.unregister(:epigenetic_supervision_observer)

      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end

      if Process.alive?(fake_daemon), do: GenServer.stop(fake_daemon)

      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, {Core.MetabolicDaemon, []})
      end
    end)

    :ok
  end

  test "differentiation as motor cell" do
    dna_path = Path.expand("../../priv/dna/motor_cell.yml")
    control_plane = EpigeneticSupervisor.control_plane_for(dna_path)

    assert control_plane.differentiation_role == :motor
    assert control_plane.metabolism.spawn_pressure_refusal == :high
    refute control_plane.apoptosis.speculative

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
    assert_received {:differentiation_event_persisted, event}
    assert event["role"] == "motor"
    assert event["pressure"] == "low"
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

  test "medium pressure refuses speculative high-atp spawn profiles" do
    GenServer.stop(Process.whereis(Core.MetabolicDaemon))
    {:ok, pid} = GenServer.start_link(FakeMetabolicDaemon, :medium, name: Core.MetabolicDaemon)

    dna_path = "/tmp/speculative_high_atp.yml"

    File.write!(dna_path, """
    id: "speculative_high_atp"
    cell_type: "speculative"
    allowed_actions: []
    atp_requirement: 1.2
    """)

    on_exit(fn ->
      File.rm(dna_path)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    assert {:error, :metabolic_starvation} = EpigeneticSupervisor.spawn_cell(dna_path)
    assert_received {:differentiation_event_persisted, event}
    assert event["spawn_admission"]["status"] == "deferred"
    assert event["spawn_admission"]["pressure"] == "medium"
  end

  test "control plane exposes speculative apoptosis policy" do
    dna_path = "/tmp/speculative_control_plane.yml"

    File.write!(dna_path, """
    cell_type: speculative
    allowed_actions: []
    utility_threshold: 0.8
    atp_requirement: 0.3
    """)

    on_exit(fn -> File.rm(dna_path) end)

    control_plane = EpigeneticSupervisor.control_plane_for(dna_path)

    assert control_plane.differentiation_role == :speculative
    assert control_plane.apoptosis.speculative
    assert control_plane.apoptosis.prune_on_surprise_over == 0.8
    assert control_plane.metabolism.atp_requirement == 0.3
  end

  test "environmental transcription prefers requested role from candidate variants" do
    motor_path = Path.expand("../../priv/dna/motor_cell.yml")
    sensory_path = Path.expand("../../priv/dna/sensory_cell.yml")

    {dna, decision} =
      EpigeneticSupervisor.transcribe_environment(
        motor_path,
        variants: [motor_path, sensory_path],
        desired_role: :sensory,
        graph_context: %{active_goal: "observe_repo"}
      )

    assert Core.DNA.role(dna) == :sensory
    assert decision["role"] == "sensory"
    assert decision["desired_role"] == "sensory"
    assert decision["graph_context"]["active_goal"] == "observe_repo"
  end

  test "environmental transcription under medium pressure avoids speculative cells" do
    speculative_path = Path.expand("../../priv/dna/speculative_cell.yml")
    motor_path = Path.expand("../../priv/dna/motor_cell.yml")

    {dna, decision} =
      EpigeneticSupervisor.transcribe_environment(
        speculative_path,
        variants: [speculative_path, motor_path],
        pressure: :medium
      )

    assert Core.DNA.role(dna) == :motor
    assert decision["role"] == "motor"
    assert "speculative" in decision["candidate_roles"]
  end
end
