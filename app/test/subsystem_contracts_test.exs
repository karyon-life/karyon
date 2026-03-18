defmodule App.SubsystemContractsTest do
  use ExUnit.Case, async: true

  alias App.TestSupport.SubsystemContracts

  test "chapter 3 subsystem contracts are satisfied across the umbrella" do
    failures = SubsystemContracts.failures()

    assert failures == [], SubsystemContracts.format_failures(failures)
  end

  test "subsystem ownership stays isolated to its intended boundary" do
    ownership_failures =
      SubsystemContracts.evaluate()
      |> Enum.filter(fn result ->
        result.forbidden_hits != []
      end)

    assert ownership_failures == [], SubsystemContracts.format_failures(ownership_failures)
  end
end
