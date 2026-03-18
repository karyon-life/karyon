defmodule Core.CytoplasmConformanceTest do
  use ExUnit.Case, async: false

  alias Core.EpigeneticSupervisor

  @dna_path Path.expand("../../../../priv/dna/motor_cell.yml", __DIR__)

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(opts \\ []) do
      pressure = Keyword.get(opts, :pressure, :low)
      GenServer.start_link(__MODULE__, pressure, name: Core.MetabolicDaemon)
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

    {:ok, fake_daemon} = FakeMetabolicDaemon.start_link()

    Enum.each(EpigeneticSupervisor.active_cells(), &EpigeneticSupervisor.apoptosis/1)
    Process.sleep(150)

    on_exit(fn ->
      if Process.alive?(fake_daemon), do: GenServer.stop(fake_daemon)

      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, {Core.MetabolicDaemon, []})
      end
    end)

    :ok
  end

  test "localized apoptosis preserves supervisor liveness and peer discovery" do
    pids =
      for _ <- 1..12 do
        {:ok, pid} = EpigeneticSupervisor.spawn_cell(@dna_path)
        pid
      end

    assert EpigeneticSupervisor.active_cell_count() == 12

    [victim | _] = pids
    assert :ok = EpigeneticSupervisor.apoptosis(victim)
    Process.sleep(150)

    assert Process.alive?(Process.whereis(EpigeneticSupervisor))
    assert EpigeneticSupervisor.active_cell_count() == 11
    assert {:ok, discovered_pid} = EpigeneticSupervisor.discover_cell(:motor)
    assert discovered_pid != victim
    assert Process.alive?(discovered_pid)
  end
end
