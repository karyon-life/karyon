defmodule Dashboard.OperatorFeedbackTest do
  use ExUnit.Case, async: true

  defmodule MemoryStub do
    def submit_operator_feedback_event(event) do
      send(self(), {:dashboard_feedback_submitted, event})
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

  test "submit/1 forwards bounded feedback events to the core feedback surface" do
    assert {:ok, %{id: id, pathway_update: %{"type" => "prune_phrase_pathway"}}} =
             Dashboard.OperatorFeedback.submit(%{
               feedback_kind: "friction",
               template_id: "operator.status.degraded",
               target_path: "summary"
             })

    assert is_binary(id)
    assert_received {:dashboard_feedback_submitted, %{"template_id" => "operator.status.degraded"}}
  end
end
