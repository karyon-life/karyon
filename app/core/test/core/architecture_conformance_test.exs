defmodule Core.ArchitectureConformanceTest do
  use ExUnit.Case, async: true

  alias Core.TestSupport.ArchitectureRubric

  test "active-inference architecture rubric is satisfied at planning, execution, and memory boundaries" do
    failures = ArchitectureRubric.failures()

    assert failures == [], ArchitectureRubric.format_failures(failures)
  end

  test "boundary files do not expose prompt-response primitives" do
    prompt_failures =
      ArchitectureRubric.evaluate()
      |> Enum.filter(fn result ->
        Enum.any?(result.forbidden_hits, &(&1 in ["run_prompt", "chat_completion", "completion", "prompt_response"]))
      end)

    assert prompt_failures == [], ArchitectureRubric.format_failures(prompt_failures)
  end
end
