defmodule Sensory.NifRouter do
  @moduledoc """
  High-speed GenServer boundary receiving asynchronous token minting
  and pruning signals directly from the Rust NIF.
  """
  use GenServer
  require Logger
  alias Rhizome.Memory

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Pure initialization, no centralized registries or heavy loading
    {:ok, %{}}
  end

  @impl true
  def handle_info({:minted_token, id, constituent_ids}, state) do
    # Let it crash on failure to ensure pure biological execution
    {:ok, _result} = Memory.upsert_sensory_node(id, constituent_ids)
    {:noreply, state}
  end

  @impl true
  def handle_info({:trigger_apoptosis, id}, state) do
    # Executing the cascade deletion
    {:ok, _result} = Memory.delete_sensory_node(id)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("[Sensory.NifRouter] Unhandled asynchronous message: #{inspect(msg)}")
    {:noreply, state}
  end
end
