defmodule Core.LearningLoop do
  @moduledoc """
  Canonical end-to-end learning-loop contract.

  This contract makes the organism's learning cycle explicit across:

  - expectation formation from perception and planning
  - action execution and outcome persistence
  - prediction-error emission and nociception
  - structural plasticity in the Rhizome
  - sleep-cycle consolidation into temporal memory
  """

  @phase_order [:perception, :action_feedback, :prediction_error, :plasticity, :consolidation]

  @contract %{
    perception: %{
      phase: :perception,
      producer: Core.StemCell,
      purpose: "form typed expectations from perception, planning, and local beliefs",
      next_phase: :action_feedback
    },
    action_feedback: %{
      phase: :action_feedback,
      producer: Rhizome.Memory,
      purpose: "persist execution outcomes and bind action results back into the learning loop",
      next_phase: :prediction_error
    },
    prediction_error: %{
      phase: :prediction_error,
      producer: NervousSystem.PainReceptor,
      purpose: "convert failure and mismatch into typed nociception and prediction-error records",
      next_phase: :plasticity
    },
    plasticity: %{
      phase: :plasticity,
      producer: Core.StemCell,
      purpose: "reinforce or prune Rhizome pathways based on success and prediction error",
      next_phase: :consolidation
    },
    consolidation: %{
      phase: :consolidation,
      producer: Rhizome.ConsolidationManager,
      purpose: "bridge working memory into archive and consolidate sleep-cycle memory state",
      next_phase: nil
    }
  }

  def contract, do: @contract
  def phase_order, do: @phase_order
  def phase(phase), do: @contract[phase]

  def phase_name(phase) when is_atom(phase), do: phase |> to_string()

  def annotate_execution_outcome(payload) when is_map(payload) do
    payload
    |> Map.put_new("learning_phase", phase_name(:action_feedback))
    |> Map.put_new("learning_edge", "#{phase_name(:action_feedback)}->#{phase_name(:plasticity)}")
  end

  def annotate_prediction_error(payload) when is_map(payload) do
    metadata =
      payload
      |> Map.get("metadata", %{})
      |> stringify_keys()
      |> Map.put_new("learning_phase", phase_name(:prediction_error))
      |> Map.put_new("learning_edge", "#{phase_name(:prediction_error)}->#{phase_name(:plasticity)}")

    payload
    |> Map.put("metadata", metadata)
    |> Map.put_new("learning_phase", phase_name(:prediction_error))
  end

  def consolidation_metadata do
    %{
      learning_phase: phase_name(:consolidation),
      learning_edge: "#{phase_name(:plasticity)}->#{phase_name(:consolidation)}"
    }
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
