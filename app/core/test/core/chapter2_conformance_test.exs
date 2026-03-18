defmodule Core.Chapter2ConformanceTest do
  use ExUnit.Case, async: true

  alias Core.TestSupport.Chapter2Rubric

  test "chapter 2 biology-first invariants are satisfied across the predictive loop" do
    failures = Chapter2Rubric.failures()

    assert failures == [], Chapter2Rubric.format_failures(failures)
  end

  test "chapter 2 conformance forbids pointer-based placeholder plasticity in the cell loop" do
    placeholder_failures =
      Chapter2Rubric.evaluate()
      |> Enum.filter(fn result ->
        Enum.any?(result.forbidden_hits, &(&1 in ["create_pointer(", "weaken_edge("]))
      end)

    assert placeholder_failures == [], Chapter2Rubric.format_failures(placeholder_failures)
  end
end
