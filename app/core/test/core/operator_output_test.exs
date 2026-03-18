defmodule Core.OperatorOutputTest do
  use ExUnit.Case, async: true

  alias Core.ExecutionIntent
  alias Core.OperatorOutput
  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Attractor
  alias Core.Plan.Step

  test "render_status_report/1 uses deterministic bounded phrasing" do
    report = %{
      status: :degraded,
      services: %{
        xtdb: %{status: :down, detail: :timeout},
        memgraph: %{status: :up, detail: :ok},
        nats: %{status: :up, detail: :ok}
      },
      runtime: %{beam_schedulers: 8, dashboard_server: true}
    }

    assert {:ok, brief} = OperatorOutput.render_status_report(report)
    assert brief.template_id == "operator.status.degraded"
    assert brief.headline == "Organism degraded"
    assert brief.summary == "One or more required services report degraded status across 3 dependency checks."
    assert "Investigate xtdb before resuming plan-driven execution." in brief.directives
    assert "service.xtdb=down(timeout)" in brief.facts
    assert "runtime.beam_schedulers=8" in brief.facts
    assert OperatorOutput.safe?(brief)
  end

  test "render_plan_summary/1 renders a bounded operator brief from typed plan state" do
    plan = %Plan{
      attractor: %Attractor{
        id: "repair-attractor",
        kind: "SuperNode",
        properties: %{},
        target_state: %AbstractState{
          entity: "repair-attractor",
          phase: "target",
          summary: "target_state:repair-attractor",
          attributes: %{},
          needs: %{},
          values: %{},
          objective_priors: %{}
        },
        objective_priors: %{},
        needs: %{},
        values: %{}
      },
      steps: [
        %Step{
          id: "step-1",
          action: "patch_codebase",
          params: %{},
          predicted_state: %AbstractState{
            entity: "step-1",
            phase: "transition",
            summary: "patched",
            attributes: %{},
            needs: %{},
            values: %{},
            objective_priors: %{}
          }
        }
      ],
      transition_delta: %{actions: ["patch_codebase"]},
      created_at: 1_700_000_000
    }

    assert {:ok, brief} = OperatorOutput.render_plan_summary(plan)
    assert brief.template_id == "operator.plan.summary"
    assert brief.headline == "Execution plan ready"
    assert brief.summary == "Attractor repair-attractor scheduled with 1 validated steps."
    assert "transition_actions=patch_codebase" in brief.facts
    assert OperatorOutput.safe?(brief)
  end

  test "render_execution_intent/1 renders a bounded operator brief from typed membrane state" do
    {:ok, intent} =
      ExecutionIntent.new(%{
        id: "intent:test",
        action: "execute_plan",
        cell_type: "planner",
        params: %{"vm_id" => "vm-1"},
        default_args: %{},
        executor: %{"module" => "Sandbox.Executor", "function" => "capture_output"},
        created_at: 1_700_000_001
      })

    assert {:ok, brief} = OperatorOutput.render_execution_intent(intent)
    assert brief.template_id == "operator.execution_intent.summary"
    assert brief.headline == "Execution intent validated"
    assert brief.summary == "Intent intent:test authorizes execute_plan for planner."
    assert "executor=Sandbox.Executor.capture_output" in brief.facts
    assert OperatorOutput.safe?(brief)
  end

  test "safe?/1 rejects unsupported or unbounded output payloads" do
    refute OperatorOutput.safe?(%{headline: String.duplicate("x", 200)})
    assert {:error, :unsupported_status_report} = OperatorOutput.render_status_report(%{status: :unknown})
  end
end
