defmodule Sandbox.WRS do
  @moduledoc """
  World Reliability Ruleset gate for irreversible sandbox execution.
  """

  alias Sandbox.Provisioner

  @allowed_actions ["execute_plan", "capture_output", "provision_vm", "execute_patch"]
  @path_keys ["host_workspace_path", "workspace_path", "patch_target"]

  def authorize_intent(%{"action" => action} = intent) when action in @allowed_actions do
    with :ok <- validate_executor(intent),
         :ok <- validate_paths(intent),
         :ok <- validate_action_contract(action, intent) do
      {:ok,
       %{
         "decision_id" => "wrs:#{action}:#{System.unique_integer([:positive])}",
         "status" => "authorized",
         "policy" => "sandbox_only",
         "action" => action,
         "checked_at" => System.system_time(:second),
         "reason" => authorization_reason(action),
         "constraints" => %{
           "host_mutation" => "forbidden_outside_sandbox",
           "workspace_transport" => "virtio-blk-overlay",
           "requires_audit" => true,
           "requires_telemetry" => true
         }
       }}
    end
  end

  def authorize_intent(%{"action" => action}), do: {:error, {:wrs_denied, {:unsupported_action, action}}}
  def authorize_intent(_intent), do: {:error, {:wrs_denied, :missing_action}}

  defp validate_executor(%{"executor" => %{"module" => "Sandbox.Executor"}}), do: :ok
  defp validate_executor(%{"executor" => executor}), do: {:error, {:wrs_denied, {:invalid_executor, executor}}}
  defp validate_executor(_intent), do: {:error, {:wrs_denied, :missing_executor}}

  defp validate_paths(%{"params" => params}) when is_map(params) do
    params
    |> Enum.filter(fn {key, value} -> to_string(key) in @path_keys and is_binary(value) end)
    |> Enum.reduce_while(:ok, fn {_key, path}, :ok ->
      case Provisioner.verify_mount_safety(path) do
        {:ok, _safe_path} -> {:cont, :ok}
        {:error, _reason} -> {:halt, {:error, {:wrs_denied, :unsafe_host_path}}}
      end
    end)
  end

  defp validate_paths(_intent), do: :ok

  defp validate_action_contract("execute_plan", %{"plan_attractor_id" => attractor_id, "params" => %{"steps" => steps}})
       when is_binary(attractor_id) and attractor_id != "" and is_list(steps) and steps != [] do
    :ok
  end

  defp validate_action_contract("execute_plan", _intent), do: {:error, {:wrs_denied, :invalid_plan_contract}}
  defp validate_action_contract(_action, _intent), do: :ok

  defp authorization_reason("execute_plan"), do: "validated execution intent with typed plan lineage"
  defp authorization_reason("execute_patch"), do: "validated sandbox mutation request"
  defp authorization_reason("provision_vm"), do: "validated membrane provisioning request"
  defp authorization_reason("capture_output"), do: "telemetry retrieval is read-only"
end
