defmodule Core.MicrokernelSterilityTest do
  use ExUnit.Case, async: true

  alias Core.TestSupport.Chapter3Rubric

  test "chapter 3 microkernel sterility invariants are satisfied" do
    failures = Chapter3Rubric.failures()

    assert failures == [], Chapter3Rubric.format_failures(failures)
  end
end
