defmodule App.BiologyFirstInvariantsTest do
  use ExUnit.Case, async: true

  alias App.TestSupport.BiologyFirstInvariants

  test "biology-first architecture invariants are satisfied across the umbrella apps" do
    failures = BiologyFirstInvariants.failures()

    assert failures == [], BiologyFirstInvariants.format_failures(failures)
  end

  test "umbrella boundaries avoid shared-state shortcuts" do
    shared_state_failures =
      BiologyFirstInvariants.evaluate()
      |> Enum.filter(fn result ->
        Enum.any?(result.forbidden_hits, &(&1 in [":ets.new", "Process.put(", "Agent.start_link", ":global.register_name", "Registry.start_link"]))
      end)

    assert shared_state_failures == [], BiologyFirstInvariants.format_failures(shared_state_failures)
  end
end
