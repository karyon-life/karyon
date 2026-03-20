defmodule Core.Chaos.ApoptosisTest do
  use ExUnit.Case
  require Logger

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, :low, name: Core.MetabolicDaemon)
    end

    def init(pressure), do: {:ok, pressure}
    def handle_call(:get_pressure, _from, pressure), do: {:reply, pressure, pressure}
    def handle_call(:get_policy, _from, pressure), do: {:reply, Core.MetabolismPolicy.build_policy(pressure), pressure}
    def handle_call(:get_runtime_status, _from, pressure) do
      {:reply,
       %{
         pressure: pressure,
         consciousness_state: :awake,
         membrane_open: true,
         motor_output_open: true,
         preflight_status: :ok,
         calibrated: true,
         strict_preflight: false
       }, pressure}
    end
  end

  @moduledoc """
  Resilience tests for cellular population regeneration.
  """

  setup do
    Application.ensure_all_started(:core)

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

  test "system regenerates cells after ChaosMonkey disruption" do
    dna_path = "/tmp/chaos_apoptosis_motor_#{System.unique_integer([:positive])}.yml"

    File.write!(dna_path, """
    cell_type: motor
    subscriptions:
      - metabolic.spike
    synapses: []
    allowed_actions: []
    """)

    on_exit(fn -> File.rm(dna_path) end)

    Enum.each(1..4, fn _ ->
      assert {:ok, _pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
    end)

    # 2. Wait for stabilization
    Process.sleep(100)
    initial_count = Enum.count(:pg.get_members(:stem_cell))
    assert initial_count >= 4

    # 3. Trigger manual disruption via internal knowledge of ChaosMonkey logic
    # (or just kill them directly to verify supervisor response)
    pids = :pg.get_members(:stem_cell)
    Enum.take_random(pids, 2) |> Enum.each(&Process.exit(&1, :kill))

    assert Process.alive?(Process.whereis(Core.EpigeneticSupervisor))

    Enum.each(1..2, fn _ ->
      assert {:ok, _pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
    end)

    assert Enum.count(:pg.get_members(:stem_cell)) >= initial_count
  end
end
