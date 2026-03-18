defmodule Core.MaturationLifecycleTest do
  use ExUnit.Case, async: true

  alias Core.MaturationLifecycle

  test "report/1 makes baseline, telemetry, teaching, and drift phases explicit" do
    baseline_root = Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle/baselines")
    objectives_root = Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle/objectives")

    File.mkdir_p!(baseline_root)
    File.mkdir_p!(objectives_root)
    File.write!(Path.join(baseline_root, "baseline.json"), ~s({"ok":true}))

    on_exit(fn ->
      File.rm_rf(Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle"))
    end)

    report =
      MaturationLifecycle.report(
        baseline_artifacts_root: baseline_root,
        objectives_root: objectives_root,
        service_report: %{overall: :ok, services: %{}, runtime: %{}},
        baseline_task_loaded: true,
        sensory_loaded: true,
        learning_loop_loaded: true,
        stem_cell_loaded: true,
        telemetry_replay_ready: true,
        teacher_loaded: true,
        oracle_generation_ready: true,
        objective_manifest_loaded: true,
        drift_detection_ready: true
      )

    assert report.schema == "karyon.maturation-lifecycle.v1"
    assert report.overall == :ok
    assert report.lifecycle == :ready
    assert report.phases.baseline_diet.status == :ok
    assert report.phases.execution_telemetry.status == :ok
    assert report.phases.synthetic_oracle.status == :ok
    assert report.phases.intent_drift.status == :ok
    assert report.phases.baseline_diet.evidence.baseline_artifact_count == 1
  end

  test "report/1 surfaces blockers when curriculum and drift evidence are missing" do
    baseline_root = Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle_missing/baselines")
    objectives_root = Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle_missing/objectives")

    on_exit(fn ->
      File.rm_rf(Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle_missing"))
    end)

    report =
      MaturationLifecycle.report(
        baseline_artifacts_root: baseline_root,
        objectives_root: objectives_root,
        service_report: %{overall: :degraded, services: %{}, runtime: %{}},
        baseline_task_loaded: false,
        sensory_loaded: false,
        learning_loop_loaded: true,
        stem_cell_loaded: true,
        telemetry_replay_ready: false,
        teacher_loaded: false,
        oracle_generation_ready: false,
        objective_manifest_loaded: true,
        drift_detection_ready: false
      )

    assert report.overall == :degraded
    assert report.lifecycle == :emerging
    assert report.phases.baseline_diet.status == :degraded
    assert report.phases.execution_telemetry.status == :degraded
    assert report.phases.synthetic_oracle.status == :degraded
    assert report.phases.intent_drift.status == :degraded
    assert Enum.any?(report.phases.baseline_diet.blockers, &String.contains?(&1, "baseline artifact"))
    assert Enum.any?(report.phases.execution_telemetry.blockers, &String.contains?(&1, "telemetry replay hooks"))
    assert Enum.any?(report.phases.synthetic_oracle.blockers, &String.contains?(&1, "teacher-daemon"))
    assert Enum.any?(report.phases.intent_drift.blockers, &String.contains?(&1, "intent-drift detection"))
  end
end
