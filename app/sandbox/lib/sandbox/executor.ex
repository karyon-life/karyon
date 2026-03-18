defmodule Sandbox.Executor do
  @moduledoc """
  Sandbox-owned execution adapter boundary for Firecracker-backed actions.
  """

  alias Sandbox.Provisioner
  alias Sandbox.WRS

  def execute_plan(%{"id" => _intent_id, "params" => %{"steps" => _steps}} = intent) do
    with {:ok, wrs_decision} <- WRS.authorize_intent(intent),
         {:ok, plan_path} <- Provisioner.stage_execution_intent(intent, wrs_decision),
         {:ok, vm_id} <- Provisioner.provision_vm(plan_path),
         :ok <- Provisioner.run_execution_loop(vm_id, intent, wrs_decision),
         {:ok, result} <- Provisioner.capture_output(vm_id) do
      {:ok,
       result
       |> Map.put(:wrs_decision, wrs_decision)
       |> Map.put(:provenance, %{
         intent_id: intent["id"],
         plan_attractor_id: intent["plan_attractor_id"],
         plan_step_ids: intent["plan_step_ids"] || []
       })}
    end
  end

  def execute_plan(_intent), do: {:error, {:wrs_denied, :invalid_plan_contract}}

  def capture_output(%{"id" => intent_id, "params" => params, "executor" => executor} = payload) do
    case Map.get(params, "steps") do
      steps when is_list(steps) and steps != [] ->
        execute_plan(%{
          "id" => intent_id,
          "action" => Map.get(payload, "action", "execute_plan"),
          "params" => params,
          "executor" => executor,
          "plan_attractor_id" => Map.get(payload, "plan_attractor_id") || Map.get(params, "attractor") || "unknown_attractor",
          "plan_step_ids" => Map.get(payload, "plan_step_ids") || Enum.map(steps, &Map.get(&1, "id", "unknown_step"))
        })

      _ ->
        vm_id = Map.get(params, "vm_id", "default_vm")
        Provisioner.capture_output(vm_id)
    end
  end

  def capture_output(%{"params" => params}) do
    case Map.get(params, "steps") do
      steps when is_list(steps) and steps != [] ->
        execute_plan(%{
          "id" => "intent:anonymous:#{System.unique_integer([:positive])}",
          "action" => "execute_plan",
          "params" => params,
          "executor" => %{"module" => "Sandbox.Executor", "function" => "capture_output"},
          "plan_attractor_id" => Map.get(params, "attractor") || "unknown_attractor",
          "plan_step_ids" => Enum.map(steps, &Map.get(&1, "id", "unknown_step"))
        })

      _ ->
        vm_id = Map.get(params, "vm_id", "default_vm")
        Provisioner.capture_output(vm_id)
    end
  end
end
