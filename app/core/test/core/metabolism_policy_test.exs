defmodule Core.MetabolismPolicyTest do
  use ExUnit.Case

  alias Core.MetabolismPolicy
  alias Core.Plan.AbstractState
  alias Core.Plan.Attractor
  alias Core.Plan.Step

  setup do
    original = Application.get_env(:core, :sovereignty)

    on_exit(fn ->
      if original do
        Application.put_env(:core, :sovereignty, original)
      else
        Application.delete_env(:core, :sovereignty)
      end
    end)

    :ok
  end

  test "build_policy/2 exposes weighted needs, values, and objective priors" do
    policy = MetabolismPolicy.build_policy(:high)

    assert policy.pressure == :high
    assert policy.atp == 0.4
    assert policy.sovereignty["schema"] == "karyon.sovereignty.v1"
    assert policy.needs["stability"] == 1.0
    assert_in_delta policy.values["safety"], 1.08, 1.0e-6
    assert policy.objective_priors["repair"] == 1.3
    assert_in_delta policy.objective_priors["preserve_homeostasis"], 1.5, 1.0e-6
  end

  test "merge_policy/2 preserves the strongest weighted prior" do
    policy =
      MetabolismPolicy.build_policy(:medium, %{
        "needs" => %{"stability" => 0.95},
        "objective_priors" => %{"repair" => 1.5}
      })

    assert policy.needs["stability"] == 0.95
    assert policy.objective_priors["repair"] == 1.5
  end

  test "objective_weight/3 combines metabolism policy with attractor priors" do
    policy = MetabolismPolicy.build_policy(:high)

    attractor = %Attractor{
      id: "repair",
      kind: "SuperNode",
      properties: %{},
      target_state: %AbstractState{
        entity: "repair",
        phase: "target",
        summary: "repair",
        attributes: %{},
        needs: %{},
        values: %{},
        objective_priors: %{"repair" => 1.1}
      },
      objective_priors: %{"repair" => 1.1},
      needs: %{},
      values: %{}
    }

    step = %Step{
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
        objective_priors: %{"repair" => 1.2}
      }
    }

    assert MetabolismPolicy.objective_weight(policy, attractor, step) == 1.5
  end

  test "build_policy/2 merges explicit sovereign directives into runtime priorities" do
    Application.put_env(:core, :sovereignty, %{
      "hard_mandates" => %{"protect_operator" => 1.4},
      "soft_values" => %{"safety" => 1.3},
      "evolving_needs" => %{"continuity" => 1.1},
      "objective_priors" => %{"repair" => 1.2},
      "precedence" => %{
        "hard_mandates" => 1.5,
        "soft_values" => 1.1,
        "evolving_needs" => 1.2,
        "objective_priors" => 1.0
      }
    })

    policy = MetabolismPolicy.build_policy(:medium)

    assert policy.sovereignty["hard_mandates"]["protect_operator"] == 1.4
    assert_in_delta policy.values["safety"], 1.43, 1.0e-6
    assert_in_delta policy.needs["continuity"], 1.32, 1.0e-6
    assert_in_delta policy.objective_priors["protect_operator"], 2.1, 1.0e-6
  end

  test "spawn_profile/2 defers speculative work when ATP budget is exhausted" do
    dna =
      Core.DNA.from_spec!(%{
        "id" => "speculative_high_atp",
        "cell_type" => "speculative",
        "allowed_actions" => [],
        "atp_requirement" => 1.2
      })

    profile = MetabolismPolicy.spawn_profile(dna, MetabolismPolicy.build_policy(:medium))

    assert profile["status"] == "deferred"
    assert profile["pressure"] == "medium"
  end
end
