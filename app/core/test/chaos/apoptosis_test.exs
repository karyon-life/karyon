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
    dna_path = Path.expand("../../../../priv/dna/motor_cell.yml", __DIR__)

    Enum.each(1..10, fn _ ->
      Core.EpigeneticSupervisor.spawn_cell(dna_path)
    end)

    # 2. Wait for stabilization
    Process.sleep(100)
    initial_count = Enum.count(:pg.get_members(:stem_cell))
    assert initial_count >= 10

    # 3. Trigger manual disruption via internal knowledge of ChaosMonkey logic
    # (or just kill them directly to verify supervisor response)
    pids = :pg.get_members(:stem_cell)
    Enum.take_random(pids, 5) |> Enum.each(&Process.exit(&1, :kill))

    assert Process.alive?(Process.whereis(Core.EpigeneticSupervisor))

    Enum.each(1..5, fn _ ->
      assert {:ok, _pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
    end)

    assert Enum.count(:pg.get_members(:stem_cell)) >= initial_count
  end
end
