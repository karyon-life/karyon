defmodule Core.StressTester do
  @moduledoc """
  Specialized module for scalability benchmarking.
  Spawns and manages massive populations of Stem Cells to track ERTS scheduler behavior.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{active_count: 0, test_id: nil}}
  end

  @doc """
  Initiates a massive swarm spawn.
  """
  def swarm_spawn(count, dna_path) do
    GenServer.call(__MODULE__, {:swarm_spawn, count, dna_path}, 120_000)
  end

  @doc """
  Purges all cells managed by the stress tester.
  """
  def purge do
    GenServer.call(__MODULE__, :purge, 60_000)
  end

  @impl true
  def handle_call({:swarm_spawn, count, dna_path}, _from, state) do
    Logger.info("[StressTester] Initiating Swarm Spawn: #{count} cells.")
    
    # We use Task.async_stream to parallelize the spawn across schedulers
    # but we bypass EpigeneticSupervisor to avoid its metabolic checks if we want raw scale
    
    pids = 
      1..count
      |> Task.async_stream(fn _ -> 
        case Core.StemCell.start(dna_path) do
          {:ok, pid} -> pid
          _ -> nil
        end
      end, max_concurrency: :erlang.system_info(:schedulers_online) * 4, timeout: 60_000)
      |> Enum.map(fn {:ok, pid} -> pid end)
      |> Enum.filter(& &1)

    new_count = length(pids)
    Logger.info("[StressTester] Swarm Spawn Complete. Actually spawned: #{new_count}")
    
    # Store PIDs in a dedicated PG group or process list
    # For now we'll just return the count and track in state
    {:reply, {:ok, new_count}, %{state | active_count: state.active_count + new_count}}
  end

  @impl true
  def handle_call(:purge, _from, state) do
    # In a real test, we'd need the PIDs. 
    # For a benchmark, we might just kill all GenServers under StemCell module
    # or rely on :pg to find victims.
    
    # Simplified purge via pg
    members = :pg.get_members(:undifferentiated) ++ :pg.get_members(:motor) ++ :pg.get_members(:sensory)
    
    Enum.each(members, fn pid -> 
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {:reply, :ok, %{state | active_count: 0}}
  end
end
