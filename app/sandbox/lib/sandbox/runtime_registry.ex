defmodule Sandbox.RuntimeRegistry do
  @moduledoc false

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put(vm_id, runtime) do
    Agent.update(__MODULE__, &Map.put(&1, vm_id, runtime))
  end

  def get(vm_id) do
    Agent.get(__MODULE__, &Map.get(&1, vm_id))
  end

  def update(vm_id, fun) when is_function(fun, 1) do
    Agent.get_and_update(__MODULE__, fn state ->
      current = Map.get(state, vm_id, %{})
      updated = fun.(current)
      {updated, Map.put(state, vm_id, updated)}
    end)
  end
end
