defmodule Dashboard.OperatorNegotiationTest do
  use ExUnit.Case, async: true

  test "render/1 forwards refusal and negotiation events to the bounded core operator surface" do
    assert {:ok, brief} =
             Dashboard.OperatorNegotiation.render(%{
               "intent_id" => "intent:dash",
               "decision" => "negotiate",
               "action" => "execute_plan",
               "action_surface" => "mutation",
               "metabolic_risk" => "medium",
               "mandate_weight" => 0.9,
               "value_pressure" => 1.3,
               "need_pressure" => 1.1,
               "paradoxes" => []
             })

    assert brief.template_id == "operator.sovereignty.negotiate"
    assert brief.format == "karyon.operator-output.v1"
  end
end
