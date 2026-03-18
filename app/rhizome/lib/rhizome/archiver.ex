defmodule Rhizome.Archiver do
  @moduledoc """
  Automates the bitemporal ledger bridging between Memgraph and XTDB.
  Scans Memgraph for new nodes and pushes them to XTDB as immutable state.
  """
  use GenServer
  require Logger
  alias Rhizome.Memory

  @interval_ms 30_000 # 30 seconds for archival check

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_archival()
    {:ok, state}
  end

  @impl true
  def handle_info(:archive, state) do
    Logger.info("[Rhizome.Archiver] Commencing bitemporal ledger synchronization...")
    
    case Memory.bridge_working_memory_to_archive() do
      {:ok, %{message: info}} ->
        Logger.info("[Rhizome.Archiver] #{info}")

      {:error, reason} ->
        Logger.error("[Rhizome.Archiver] Ledger Sync Error: #{reason}")
    end

    schedule_archival()
    {:noreply, state}
  end

  defp schedule_archival do
    Process.send_after(self(), :archive, @interval_ms)
  end
end
