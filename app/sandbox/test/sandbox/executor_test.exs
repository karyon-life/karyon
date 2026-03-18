defmodule Sandbox.ExecutorTest do
  use ExUnit.Case, async: false

  alias Sandbox.Executor

  test "capture_output consumes typed execution-intent payloads" do
    vm_id = "vm-executor-intent"
    stdout_path = Path.join(System.tmp_dir!(), "#{vm_id}-stdout")
    stderr_path = Path.join(System.tmp_dir!(), "#{vm_id}-stderr")

    File.write!(stdout_path, "executor stdout\n")
    File.write!(stderr_path, "executor stderr\n")

    Sandbox.RuntimeRegistry.put(vm_id, %{
      stdout_path: stdout_path,
      stderr_path: stderr_path,
      exit_code: 0,
      status: :exited,
      pain_reported: false,
      workspace_mount_target: "/mnt/workspace",
      workspace_image_path: "/tmp/workspace.ext4"
    })

    intent = %{
      "id" => "intent:test",
      "action" => "capture_output",
      "cell_type" => "motor",
      "params" => %{"vm_id" => vm_id},
      "default_args" => %{},
      "executor" => %{"module" => "Sandbox.Executor", "function" => "capture_output"},
      "created_at" => System.system_time(:second)
    }

    original_mock = System.get_env("KARYON_MOCK_HARDWARE")
    System.put_env("KARYON_MOCK_HARDWARE", "0")

    on_exit(fn ->
      if original_mock do
        System.put_env("KARYON_MOCK_HARDWARE", original_mock)
      else
        System.delete_env("KARYON_MOCK_HARDWARE")
      end

      File.rm(stdout_path)
      File.rm(stderr_path)
    end)

    assert {:ok, result} = Executor.capture_output(intent)
    assert result.vm_id == vm_id
    assert result.status == :exited
    assert result.stdout == "executor stdout\n"
  end

  test "execute_plan provisions a WRS-gated sandbox loop with audit and telemetry" do
    original_mock = System.get_env("KARYON_MOCK_HARDWARE")
    System.put_env("KARYON_MOCK_HARDWARE", "1")

    on_exit(fn ->
      if original_mock do
        System.put_env("KARYON_MOCK_HARDWARE", original_mock)
      else
        System.delete_env("KARYON_MOCK_HARDWARE")
      end
    end)

    intent = %{
      "id" => "intent:sandbox-execute-plan",
      "action" => "execute_plan",
      "plan_attractor_id" => "repair-attractor",
      "plan_step_ids" => ["step-1", "step-2"],
      "executor" => %{"module" => "Sandbox.Executor", "function" => "capture_output"},
      "params" => %{
        "attractor" => "repair-attractor",
        "steps" => [
          %{"id" => "step-1", "action" => "patch_codebase", "params" => %{"file" => "lib/app.ex"}},
          %{"id" => "step-2", "action" => "run_tests", "params" => %{"suite" => "core"}}
        ],
        "transition_delta" => %{"step_count" => 2}
      },
      "transition_delta" => %{
        "metabolism_admission" => %{"status" => "admitted", "lane" => "expedite", "pressure" => "high"}
      }
    }

    assert {:ok, result} = Executor.execute_plan(intent)
    assert result.mode == :mock
    assert result.status == :exited
    assert result.metabolism_admission["lane"] == "expedite"
    assert result.wrs_decision["status"] == "authorized"
    assert result.audit["host_mutation"] == "forbidden_outside_sandbox"
    assert result.audit["plan_attractor_id"] == "repair-attractor"
    assert result.telemetry["summary"]["mutation_count"] == 2
    assert Enum.any?(result.telemetry["stages"], &(&1["name"] == "compile"))
    assert result.provenance.intent_id == "intent:sandbox-execute-plan"
  end

  test "execute_plan denies sandbox work when metabolic admission is deferred" do
    intent = %{
      "id" => "intent:sandbox-deferred",
      "action" => "execute_plan",
      "plan_attractor_id" => "refinement-attractor",
      "plan_step_ids" => ["step-1"],
      "executor" => %{"module" => "Sandbox.Executor", "function" => "capture_output"},
      "params" => %{
        "attractor" => "refinement-attractor",
        "steps" => [
          %{"id" => "step-1", "action" => "refine_notes", "params" => %{}}
        ]
      },
      "transition_delta" => %{
        "metabolism_admission" => %{"status" => "deferred", "lane" => "deferred", "pressure" => "high"}
      }
    }

    assert {:error, :insufficient_atp_budget} = Executor.execute_plan(intent)
  end
end
