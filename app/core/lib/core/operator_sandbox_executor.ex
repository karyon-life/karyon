defmodule Core.OperatorSandboxExecutor do
  @moduledoc """
  Non-execution operator membrane adapter.

  Legacy planning surfaces still emit execution intents, but they now cross a
  waking-world operator membrane instead of a remote execution membrane.
  This adapter only packages the intent into motor babble and organism-bus
  telemetry; it never provisions a VM.
  """

  @motor_topic NervousSystem.PubSub.topic(:motor_output)

  def execute_plan(intent) when is_map(intent) do
    brief =
      %{
        intent_id: Map.get(intent, "id", "intent:unknown"),
        action: Map.get(intent, "action", "unknown"),
        executor: "Core.OperatorSandboxExecutor.execute_plan",
        mode: "operator_environment"
      }

    :ok = NervousSystem.PubSub.broadcast(@motor_topic, %{stream: "motor_babble", brief: brief})

    {:ok,
     %{
       status: :accepted,
       vm_id: "operator_environment",
       exit_code: 0,
       telemetry: %{
         summary: %{
           mutation_count: 0,
           compile_count: 0,
           tests_ran: 0,
           tests_failed: 0
         },
         brief: brief
       },
       audit: %{
         membrane: "operator_environment",
         accepted_at: System.system_time(:millisecond)
       }
     }}
  end

  def execute_plan(_intent), do: {:error, :invalid_execution_intent}

  def capture_output(payload) when is_map(payload), do: execute_plan(payload)
  def capture_output(_payload), do: {:error, :invalid_execution_intent}
end
