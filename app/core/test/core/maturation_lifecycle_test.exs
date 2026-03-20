defmodule Core.MaturationLifecycleTest do
  use ExUnit.Case, async: true

  alias Core.MaturationLifecycle

  test "report/1 makes babbling, phoneme, grammar, and semantic phases explicit" do
    dna_root = Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle/dna")

    File.mkdir_p!(dna_root)
    Enum.each([
      "sensory_pooler_cell.yml",
      "motor_babble_cell.yml",
      "tabula_rasa_stem_cell.yml"
    ], fn file ->
      File.write!(Path.join(dna_root, file), "cell_type: placeholder\n")
    end)

    on_exit(fn ->
      File.rm_rf(Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle"))
    end)

    report =
      MaturationLifecycle.report(
        dna_root: dna_root,
        service_report: %{overall: :ok, services: %{}, runtime: %{}},
        sensory_pooler_loaded: true,
        motor_babble_loaded: true,
        raw_input_ready: true,
        raw_output_ready: true,
        learning_loop_loaded: true,
        stem_cell_loaded: true,
        pooled_sequences_ready: true,
        sensory_memory_ready: true,
        consolidation_manager_loaded: true,
        sleep_cycle_ready: true,
        grammar_supernodes_ready: true,
        operator_feedback_ready: true,
        semantic_feedback_ready: true,
        durable_grounding_ready: true
      )

    assert report.schema == "karyon.maturation-lifecycle.v2"
    assert report.overall == :ok
    assert report.lifecycle == :ready
    assert report.phases.babbling.status == :ok
    assert report.phases.phoneme_grounding.status == :ok
    assert report.phases.grammar_consolidation.status == :ok
    assert report.phases.semantic_grounding.status == :ok
    assert length(report.phases.babbling.evidence.baseline_dna_present) == 3
  end

  test "report/1 surfaces blockers when linguistic grounding evidence is missing" do
    dna_root = Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle_missing/dna")

    on_exit(fn ->
      File.rm_rf(Path.join(System.tmp_dir!(), "karyon_maturation_lifecycle_missing"))
    end)

    report =
      MaturationLifecycle.report(
        dna_root: dna_root,
        service_report: %{overall: :degraded, services: %{}, runtime: %{}},
        sensory_pooler_loaded: false,
        motor_babble_loaded: false,
        raw_input_ready: false,
        raw_output_ready: false,
        learning_loop_loaded: true,
        stem_cell_loaded: true,
        pooled_sequences_ready: false,
        sensory_memory_ready: false,
        consolidation_manager_loaded: false,
        sleep_cycle_ready: false,
        grammar_supernodes_ready: false,
        operator_feedback_ready: false,
        semantic_feedback_ready: false,
        durable_grounding_ready: false
      )

    assert report.overall == :degraded
    assert report.lifecycle == :emerging
    assert report.phases.babbling.status == :degraded
    assert report.phases.phoneme_grounding.status == :degraded
    assert report.phases.grammar_consolidation.status == :degraded
    assert report.phases.semantic_grounding.status == :degraded
    assert Enum.any?(report.phases.babbling.blockers, &String.contains?(&1, "baseline linguistic DNA"))
    assert Enum.any?(report.phases.phoneme_grounding.blockers, &String.contains?(&1, "sensory pools"))
    assert Enum.any?(report.phases.grammar_consolidation.blockers, &String.contains?(&1, "consolidation manager"))
    assert Enum.any?(report.phases.semantic_grounding.blockers, &String.contains?(&1, "semantic feedback"))
  end
end
