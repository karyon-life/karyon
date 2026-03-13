defmodule CoreTest do
  use ExUnit.Case

  test "metabolic daemon monitors CPU run queues" do
    assert Process.whereis(Core.MetabolicDaemon) != nil
  end
end
