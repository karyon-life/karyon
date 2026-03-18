defmodule Core.MaturationLifecycle do
  @moduledoc """
  Typed maturation lifecycle contract for Chapter 12.

  This makes the organism's baseline curriculum, telemetry curriculum,
  teacher-guided refinement, and intent-drift correction explicit so later
  Chapter 12 work can extend one shared lifecycle surface instead of
  introducing disconnected maturation logic.
  """

  alias Core.ObjectiveManifest
  alias Core.ServiceHealth

  @schema "karyon.maturation-lifecycle.v1"
  @baseline_validation "cd /home/adrian/Projects/nexical/karyon/app && mix karyon.baseline"
  @telemetry_validation "cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test apps/rhizome/test"
  @teacher_validation "cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test"
  @drift_validation "cd /home/adrian/Projects/nexical/karyon/app && mix test apps/core/test/core/objective_manifest_test.exs"

  def report(opts \\ []) do
    service_report = Keyword.get_lazy(opts, :service_report, fn -> ServiceHealth.check_all() end)
    baseline_root = Keyword.get(opts, :baseline_artifacts_root, baseline_artifacts_root())
    objectives_root = Keyword.get(opts, :objectives_root, ObjectiveManifest.root_dir())

    phases = %{
      baseline_diet: baseline_diet_phase(baseline_root, opts),
      execution_telemetry: execution_telemetry_phase(service_report, opts),
      synthetic_oracle: synthetic_oracle_phase(opts),
      intent_drift: intent_drift_phase(objectives_root, opts)
    }

    %{
      schema: @schema,
      overall: overall_status(phases),
      lifecycle: lifecycle_status(phases),
      phases: phases
    }
  end

  def baseline_artifacts_root do
    Application.get_env(:core, :baseline_artifacts_root, Path.expand("../../../artifacts/benchmarks", __DIR__))
  end

  defp baseline_diet_phase(root, opts) do
    expanded_root = Path.expand(root)
    baseline_task_loaded? = loaded?(opts, :baseline_task_loaded, Mix.Tasks.Karyon.Baseline)
    sensory_loaded? = loaded?(opts, :sensory_loaded, Sensory.Native)
    artifact_count = baseline_artifact_count(expanded_root)

    blockers =
      []
      |> maybe_add(not baseline_task_loaded?, "load Mix.Tasks.Karyon.Baseline before treating baseline intake as executable curriculum")
      |> maybe_add(not sensory_loaded?, "load the sensory parsing organ so deterministic AST curriculum can exist")
      |> maybe_add(artifact_count == 0, "record at least one baseline artifact under #{expanded_root} to ground maturation in a deterministic substrate")

    %{
      status: status_from_blockers(blockers),
      objective: "Establish a deterministic structural grammar baseline before higher-order action loops dominate.",
      validation: @baseline_validation,
      next_phase: "C12-S02",
      blockers: blockers,
      evidence: %{
        baseline_artifacts_root: expanded_root,
        baseline_artifact_count: artifact_count,
        baseline_task_loaded: baseline_task_loaded?,
        sensory_loaded: sensory_loaded?
      }
    }
  end

  defp execution_telemetry_phase(service_report, opts) do
    learning_loop_loaded? = loaded?(opts, :learning_loop_loaded, Core.LearningLoop)
    stem_cell_loaded? = loaded?(opts, :stem_cell_loaded, Core.StemCell)
    telemetry_replay_ready? = Keyword.get(opts, :telemetry_replay_ready, false)
    service_overall = Map.get(service_report, :overall, :degraded)

    blockers =
      []
      |> maybe_add(not learning_loop_loaded?, "load the learning loop contract before promoting telemetry to curriculum input")
      |> maybe_add(not stem_cell_loaded?, "load the stem-cell execution boundary before treating execution outcomes as reusable training evidence")
      |> maybe_add(service_overall != :ok, "restore Memgraph, XTDB, and NATS readiness before relying on telemetry-backed maturation")
      |> maybe_add(not telemetry_replay_ready?, "implement telemetry replay hooks before claiming execution evidence can drive maturation")

    %{
      status: status_from_blockers(blockers),
      objective: "Treat execution telemetry as replayable curriculum evidence instead of transient logs.",
      validation: @telemetry_validation,
      next_phase: "C12-S03",
      blockers: blockers,
      evidence: %{
        service_overall: to_string(service_overall),
        learning_loop_loaded: learning_loop_loaded?,
        stem_cell_loaded: stem_cell_loaded?,
        telemetry_replay_ready: telemetry_replay_ready?
      }
    }
  end

  defp synthetic_oracle_phase(opts) do
    teacher_loaded? = Keyword.get(opts, :teacher_loaded, false)
    oracle_generation_ready? = Keyword.get(opts, :oracle_generation_ready, false)

    blockers =
      []
      |> maybe_add(not teacher_loaded?, "load a teacher-daemon boundary before claiming guided curriculum exists")
      |> maybe_add(not oracle_generation_ready?, "implement synthetic oracle generation before treating exams as a real maturation phase")

    %{
      status: status_from_blockers(blockers),
      objective: "Refine the organism through teacher-guided evaluation and synthetic oracle exams.",
      validation: @teacher_validation,
      next_phase: "C12-S04",
      blockers: blockers,
      evidence: %{
        teacher_loaded: teacher_loaded?,
        oracle_generation_ready: oracle_generation_ready?
      }
    }
  end

  defp intent_drift_phase(root, opts) do
    expanded_root = Path.expand(root)
    objective_manifest_loaded? = loaded?(opts, :objective_manifest_loaded, Core.ObjectiveManifest)
    drift_detection_ready? = Keyword.get(opts, :drift_detection_ready, false)
    objectives_root_exists? = File.dir?(expanded_root)

    blockers =
      []
      |> maybe_add(not objective_manifest_loaded?, "load the objective manifest boundary before correcting intent drift")
      |> maybe_add(not objectives_root_exists?, "create #{expanded_root} so evolving needs and values have persistent objective input")
      |> maybe_add(not drift_detection_ready?, "implement intent-drift detection before claiming the lifecycle can correct mandate divergence")

    %{
      status: status_from_blockers(blockers),
      objective: "Detect and correct drift between sovereign intent, evolving needs, and runtime behavior.",
      validation: @drift_validation,
      next_phase: "C12-S05",
      blockers: blockers,
      evidence: %{
        objectives_root: expanded_root,
        objectives_root_exists: objectives_root_exists?,
        objective_manifest_loaded: objective_manifest_loaded?,
        drift_detection_ready: drift_detection_ready?
      }
    }
  end

  defp baseline_artifact_count(root) do
    root
    |> Path.join("*.json")
    |> Path.wildcard()
    |> length()
  end

  defp loaded?(opts, key, module) do
    Keyword.get_lazy(opts, key, fn -> Code.ensure_loaded?(module) end)
  end

  defp overall_status(phases) do
    if Enum.all?(phases, fn {_name, phase} -> phase.status == :ok end) do
      :ok
    else
      :degraded
    end
  end

  defp lifecycle_status(phases) do
    if Enum.all?(phases, fn {_name, phase} -> phase.status == :ok end) do
      :ready
    else
      :emerging
    end
  end

  defp status_from_blockers([]), do: :ok
  defp status_from_blockers(_blockers), do: :degraded

  defp maybe_add(list, true, entry), do: list ++ [entry]
  defp maybe_add(list, false, _entry), do: list
end
