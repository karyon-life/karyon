defmodule Core.TeacherDaemonTest do
  use ExUnit.Case, async: true

  alias Core.TeacherDaemon

  defmodule ExecutorStub do
    def execute_plan(intent) do
      send(self(), {:teacher_intent, intent})

      {:ok,
       %{
         status: :exited,
         vm_id: "operator_environment",
         exit_code: 0,
         telemetry: %{
           summary: %{
              mutation_count: 1,
             compile_count: 1,
             tests_ran: 2,
             tests_failed: 0
           }
         },
         audit: %{"plan_attractor_id" => intent["plan_attractor_id"]}
       }}
    end
  end

  defmodule MemoryStub do
    def submit_teacher_daemon_event(event) do
      send(self(), {:teacher_event_persisted, event})
      {:ok, %{id: event["teacher_event_id"]}}
    end

    def submit_execution_telemetry(telemetry) do
      send(self(), {:teacher_telemetry_persisted, telemetry})
      {:ok, %{id: telemetry["telemetry_id"]}}
    end
  end

  test "generate_exams/2 derives bounded curriculum exams from docs and specs" do
    doc_path = write_fixture!("teacher_daemon_doc.md", "# Zero Locks\nUse actor isolation over global mutexes.\n")
    spec_path = write_fixture!("teacher_daemon_spec.md", "# Sterility\nKeep domain logic out of the core kernel.\n")

    assert {:ok, exams} = TeacherDaemon.generate_exams([spec_path, doc_path], max_exams: 2, confidence_threshold: 0.65)

    assert length(exams) == 2
    assert Enum.all?(exams, &(&1["schema"] == "karyon.teacher-daemon.v1"))
    assert Enum.any?(exams, &(&1["headline"] == "Zero Locks"))
    assert Enum.any?(exams, &(&1["headline"] == "Sterility"))
    assert Enum.all?(exams, &(String.length(&1["prompt"]) <= 240))
  end

  test "administer_exam/2 runs a bounded synthetic exam through the operator membrane and persists curriculum evidence" do
    exam = %{
      "exam_id" => "teacher_exam:test",
      "schema" => "karyon.teacher-daemon.v1",
      "source_path" => "/tmp/spec.md",
      "source_kind" => "spec",
      "headline" => "Sterility",
      "prompt" => "Implement a bounded architectural exam without introducing a global mutex.",
      "confidence_threshold" => 0.7,
      "curriculum_scope" => "specification"
    }

    assert {:ok, result} =
             TeacherDaemon.administer_exam(
               exam,
               executor_module: ExecutorStub,
               memory_module: MemoryStub,
               workspace_root: Path.join(System.tmp_dir!(), "teacher-daemon-workspace"),
               vm_id: "operator_environment"
             )

    assert result.result.vm_id == "operator_environment"
    assert_received {:teacher_intent, intent}
    assert intent["action"] == "execute_plan"
    assert_received {:teacher_event_persisted, event}
    assert event["exam_id"] == "teacher_exam:test"
    assert event["outcome_status"] == "success"
    assert_received {:teacher_telemetry_persisted, telemetry}
    assert telemetry["schema"] == "karyon.execution-telemetry.v1"
    assert telemetry["result_summary"]["tests_ran"] == 2
  end

  defp write_fixture!(name, body) do
    path = Path.join(System.tmp_dir!(), "#{name}-#{System.unique_integer([:positive])}")
    File.write!(path, body)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
