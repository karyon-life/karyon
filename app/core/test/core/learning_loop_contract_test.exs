defmodule Core.LearningLoopContractTest do
  use ExUnit.Case, async: true

  test "learning loop contract exposes the ordered cross-app phases" do
    assert Core.LearningLoop.phase_order() ==
             [:perception, :action_feedback, :prediction_error, :plasticity, :consolidation]

    contract = Core.LearningLoop.contract()

    assert contract.perception.producer == Core.StemCell
    assert contract.action_feedback.producer == Rhizome.Memory
    assert contract.prediction_error.producer == NervousSystem.PainReceptor
    assert contract.plasticity.producer == Core.StemCell
    assert contract.consolidation.producer == Rhizome.ConsolidationManager
  end

  test "learning loop annotations make action, failure, and consolidation phases explicit" do
    outcome = Core.LearningLoop.annotate_execution_outcome(%{"action" => "patch_codebase"})

    assert outcome["learning_phase"] == "action_feedback"
    assert outcome["learning_edge"] == "action_feedback->plasticity"

    prediction_error =
      Core.LearningLoop.annotate_prediction_error(%{"type" => "execution_failure", "metadata" => %{}})

    assert prediction_error["learning_phase"] == "prediction_error"
    assert prediction_error["metadata"]["learning_phase"] == "prediction_error"
    assert prediction_error["metadata"]["learning_edge"] == "prediction_error->plasticity"

    assert %{learning_phase: "consolidation", learning_edge: "plasticity->consolidation"} =
             Core.LearningLoop.consolidation_metadata()
  end
end
