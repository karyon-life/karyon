defmodule Sandbox.WRSTest do
  use ExUnit.Case, async: true

  alias Sandbox.WRS

  test "authorize_intent/1 accepts typed sandbox plans with lineage and steps" do
    intent = %{
      "id" => "intent:wrs-allow",
      "action" => "execute_plan",
      "plan_attractor_id" => "repair-attractor",
      "plan_step_ids" => ["step-1"],
      "executor" => %{"module" => "Sandbox.Executor", "function" => "capture_output"},
      "transition_delta" => %{"workspace_root" => Path.join(System.tmp_dir!(), "karyon-target-wrs")},
      "params" => %{
        "steps" => [
          %{"id" => "step-1", "action" => "patch_codebase", "params" => %{}}
        ]
      }
    }

    assert {:ok, decision} = WRS.authorize_intent(intent)
    assert decision["status"] == "authorized"
    assert decision["policy"] == "sandbox_only"
    assert decision["constraints"]["host_mutation"] == "forbidden_outside_sandbox"
  end

  test "authorize_intent/1 denies unsafe host paths" do
    intent = %{
      "id" => "intent:wrs-deny",
      "action" => "execute_plan",
      "plan_attractor_id" => "repair-attractor",
      "executor" => %{"module" => "Sandbox.Executor", "function" => "capture_output"},
      "transition_delta" => %{"workspace_root" => Path.join(System.tmp_dir!(), "karyon-target-wrs")},
      "params" => %{
        "steps" => [
          %{"id" => "step-1", "action" => "patch_codebase", "params" => %{}}
        ],
        "host_workspace_path" => "/etc/passwd"
      }
    }

    assert {:error, {:wrs_denied, :unsafe_host_path}} = WRS.authorize_intent(intent)
  end

  test "authorize_intent/1 denies execute_plan intents that target the engine workspace" do
    intent = %{
      "id" => "intent:wrs-engine-deny",
      "action" => "execute_plan",
      "plan_attractor_id" => "repair-attractor",
      "executor" => %{"module" => "Sandbox.Executor", "function" => "capture_output"},
      "transition_delta" => %{"workspace_root" => Sandbox.MonorepoPipeline.engine_root()},
      "params" => %{
        "steps" => [
          %{"id" => "step-1", "action" => "patch_codebase", "params" => %{}}
        ]
      }
    }

    assert {:error, {:wrs_denied, :engine_workspace_forbidden}} = WRS.authorize_intent(intent)
  end
end
