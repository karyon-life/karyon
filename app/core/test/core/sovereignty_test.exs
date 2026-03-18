defmodule Core.SovereigntyTest do
  use ExUnit.Case, async: true

  alias Core.Sovereignty

  test "current_state/1 normalizes weighted mandates, values, needs, and precedence" do
    state =
      Sovereignty.current_state(%{
        "hard_mandates" => %{"protect_operator" => 1.4},
        "soft_values" => %{"safety" => 1.2},
        "evolving_needs" => %{"continuity" => 1.1},
        "objective_priors" => %{"repair" => 1.3},
        "precedence" => %{"hard_mandates" => 1.6}
      })

    assert state.schema == "karyon.sovereignty.v1"
    assert state.hard_mandates["protect_operator"] == 1.4
    assert state.soft_values["safety"] == 1.2
    assert state.evolving_needs["continuity"] == 1.1
    assert state.objective_priors["repair"] == 1.3
    assert state.precedence["hard_mandates"] == 1.6
  end

  test "policy_overrides/1 projects weighted mandates into objective priors" do
    overrides =
      Sovereignty.policy_overrides(%{
        hard_mandates: %{"preserve_homeostasis" => 1.2},
        soft_values: %{"safety" => 1.1},
        evolving_needs: %{"continuity" => 0.9},
        objective_priors: %{"repair" => 1.0},
        precedence: %{
          "hard_mandates" => 1.5,
          "soft_values" => 1.2,
          "evolving_needs" => 1.1,
          "objective_priors" => 1.0
        }
      })

    assert_in_delta overrides.objective_priors["preserve_homeostasis"], 1.8, 1.0e-6
    assert_in_delta overrides.values["safety"], 1.32, 1.0e-6
    assert_in_delta overrides.needs["continuity"], 0.99, 1.0e-6
  end
end
