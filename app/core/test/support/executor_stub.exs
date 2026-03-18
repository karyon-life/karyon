defmodule Core.TestSupport.ExecutorStub do
  @moduledoc false

  alias Core.ExecutionIntent

  def capture_output(%ExecutionIntent{} = intent) do
    intent
    |> ExecutionIntent.to_map()
    |> capture_output()
  end

  def capture_output(%{"id" => _, "params" => params, "executor" => _executor}) do
    vm_id = params["vm_id"] || "default_vm"

    {:ok, %{exit_code: 0, mode: :mock, vm_id: vm_id, stdout: "mock execution", stderr: ""}}
  end

  def capture_output(%{"params" => params}) do
    vm_id = params["vm_id"] || "default_vm"

    {:ok, %{exit_code: 0, mode: :mock, vm_id: vm_id, stdout: "mock execution", stderr: ""}}
  end

  def simulate_failure(%ExecutionIntent{} = intent) do
    intent
    |> ExecutionIntent.to_map()
    |> simulate_failure()
  end

  def simulate_failure(%{"action" => _action}) do
    {:error, :simulated_failure}
  end
end
