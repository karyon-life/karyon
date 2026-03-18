defmodule Sandbox.Executor do
  @moduledoc """
  Sandbox-owned execution adapter boundary for Firecracker-backed actions.
  """

  def capture_output(%{"params" => params}) do
    vm_id = Map.get(params, "vm_id", "default_vm")
    Sandbox.Provisioner.capture_output(vm_id)
  end
end
