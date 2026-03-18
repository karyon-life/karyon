defmodule Core.SovereignGuardTest do
  use ExUnit.Case, async: true

  alias Core.ExecutionIntent
  alias Core.SovereignGuard

  test "evaluate_intent/3 refuses mutation when homeostasis mandate conflicts with high metabolic risk" do
    {:ok, intent} =
      ExecutionIntent.new(%{
        id: "intent:refuse",
        action: "execute_plan",
        cell_type: "planner",
        params: %{"steps" => [%{"action" => "patch_codebase"}]},
        default_args: %{},
        executor: %{"module" => "Sandbox.Executor", "function" => "capture_output"},
        created_at: 1_710_000_020
      })

    state = %{lineage_id: "planner-lineage", atp_metabolism: 0.4}

    policy =
      Core.MetabolismPolicy.build_policy(:high, %{
        "sovereignty" => %{
          "hard_mandates" => %{"preserve_homeostasis" => 1.4},
          "soft_values" => %{"safety" => 1.2},
          "evolving_needs" => %{"continuity" => 1.1},
          "precedence" => %{"hard_mandates" => 1.5}
        }
      })

    assert {:refuse, event} = SovereignGuard.evaluate_intent(intent, state, policy: policy)
    assert event["decision"] == "refuse"
    assert event["event_kind"] == "refusal"
    assert "homeostasis_conflict" in event["paradoxes"]
    assert event["operator_brief"].template_id == "operator.sovereignty.refuse"
  end

  test "evaluate_intent/3 negotiates when safety and continuity pressure exceed current homeostatic margin" do
    {:ok, intent} =
      ExecutionIntent.new(%{
        id: "intent:negotiate",
        action: "execute_plan",
        cell_type: "planner",
        params: %{"steps" => [%{"action" => "patch_codebase"}]},
        default_args: %{},
        executor: %{"module" => "Sandbox.Executor", "function" => "capture_output"},
        created_at: 1_710_000_021
      })

    state = %{lineage_id: "planner-lineage", atp_metabolism: 0.65}

    policy =
      Core.MetabolismPolicy.build_policy(:medium, %{
        "sovereignty" => %{
          "soft_values" => %{"safety" => 1.3},
          "evolving_needs" => %{"continuity" => 1.2}
        }
      })

    assert {:negotiate, event} = SovereignGuard.evaluate_intent(intent, state, policy: policy)
    assert event["decision"] == "negotiate"
    assert event["event_kind"] == "negotiation"
    assert event["operator_brief"].template_id == "operator.sovereignty.negotiate"
  end
end
