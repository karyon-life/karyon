defmodule Core.OperatorFeedbackTest do
  use ExUnit.Case, async: true

  alias Core.OperatorFeedback

  defmodule MemoryStub do
    def submit_operator_feedback_event(event) do
      send(self(), {:operator_feedback_persisted, event})
      {:ok, %{id: event["id"]}}
    end
  end

  setup do
    original = Application.get_env(:core, :memory_module)
    Application.put_env(:core, :memory_module, MemoryStub)

    on_exit(fn ->
      if original do
        Application.put_env(:core, :memory_module, original)
      else
        Application.delete_env(:core, :memory_module)
      end
    end)

    :ok
  end

  test "record_event/1 persists bounded socio-linguistic friction events" do
    assert {:ok, %{id: id, pathway_update: pathway_update}} =
             OperatorFeedback.record_event(%{
               feedback_kind: "friction",
               template_id: "operator.status.degraded",
               target_path: "summary",
               operator_id: "clinician-1",
               friction_level: :high,
               message: "too abrupt"
             })

    assert is_binary(id)
    assert pathway_update["type"] == "prune_phrase_pathway"
    assert_received {:operator_feedback_persisted, event}
    assert event["scope"] == "socio_linguistic"
    assert event["core_decision_scope"] == "protected"
    assert event["target_domain"] == "operator_output"
    assert event["metadata"]["separate_from_core_logic"] == true
  end

  test "record_event/1 reinforces approved phrasing pathways" do
    assert {:ok, %{pathway_update: pathway_update}} =
             OperatorFeedback.record_event(%{
               feedback_kind: "approval",
               template_id: "operator.status.ok",
               target_path: "headline"
             })

    assert pathway_update["type"] == "reinforce_phrase_pathway"
    assert pathway_update["weight_delta"] == 0.2
  end

  test "record_event/1 rejects attempts to target protected core domains" do
    assert {:error, :core_logic_protected} =
             OperatorFeedback.record_event(%{
               feedback_kind: "correction",
               template_id: "operator.status.ok",
               target_path: "headline",
               target_domain: "core_planning"
             })
  end
end
