defmodule Core.ExecutionTelemetryTest do
  use ExUnit.Case, async: true

  alias Core.ExecutionTelemetry

  defmodule MemoryStub do
    def query_recent_execution_telemetry(%{limit: 1}) do
      {:ok,
       [
         %{
           "telemetry_id" => "execution_telemetry:1",
           "schema" => "karyon.execution-telemetry.v1",
           "action" => "patch_codebase",
           "status" => "success"
         }
       ]}
    end
  end

  test "from_execution_outcome/1 standardizes tags, provenance, and replay summary" do
    telemetry =
      ExecutionTelemetry.from_execution_outcome(%{
        "id" => "execution_outcome:planner:patch_codebase:1",
        "cell_id" => "planner",
        "action" => "patch_codebase",
        "status" => "success",
        "executor" => "Core.OperatorSandboxExecutor.execute_plan",
        "vm_id" => "operator_environment",
        "exit_code" => 0,
        "learning_phase" => "action_feedback",
        "learning_edge" => "action_feedback->plasticity",
        "execution_intent_id" => "intent:planner:patch_codebase:1",
        "result" => %{
          "stdout" => "ok",
          "summary" => %{
            "mutation_count" => 2,
            "compile_count" => 1,
            "tests_ran" => 4,
            "tests_failed" => 0
          }
        }
      })

    assert telemetry["schema"] == "karyon.execution-telemetry.v1"
    assert telemetry["source_document_id"] == "execution_outcome:planner:patch_codebase:1"
    assert "action:patch_codebase" in telemetry["tags"]
    assert "mutations_recorded" in telemetry["tags"]
    assert telemetry["provenance"]["execution_intent_id"] == "intent:planner:patch_codebase:1"
    assert telemetry["result_summary"]["tests_ran"] == 4
    assert telemetry["result_summary"]["compile_count"] == 1
  end

  test "replay_recent/1 returns typed telemetry artifacts" do
    assert {:ok, [telemetry]} =
             ExecutionTelemetry.replay_recent(memory_module: MemoryStub, limit: 1)

    assert telemetry["schema"] == "karyon.execution-telemetry.v1"
    assert telemetry["action"] == "patch_codebase"
    assert telemetry["status"] == "success"
  end
end
