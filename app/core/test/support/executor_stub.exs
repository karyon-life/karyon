defmodule Core.TestSupport.ExecutorStub do
  @moduledoc false

  def capture_output(%{"params" => params}) do
    vm_id = params["vm_id"] || "default_vm"

    {:ok, %{exit_code: 0, mode: :mock, vm_id: vm_id, stdout: "mock execution", stderr: ""}}
  end

  def simulate_failure(%{"action" => _action}) do
    {:error, :simulated_failure}
  end
end
