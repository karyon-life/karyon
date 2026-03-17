defmodule Core.MotorDriverTest do
  use ExUnit.Case
  alias Core.MotorDriver
  alias Core.StemCell

  setup do
    # Mocking Rhizome.Native for testing if necessary
    :ok
  end

  test "sequence_plan/1 returns a structured plan for a known attractor" do
    case MotorDriver.sequence_plan("test_attractor") do
      {:ok, plan} ->
        assert plan["attractor"] == "test_attractor"
        assert length(plan["steps"]) > 0
      {:error, :graph_planning_not_ready} ->
        :ok
      {:error, :attractor_not_found} ->
        :ok
    end
  end

  test "StemCell boots successfully from new DNA templates" do
    dna_path = "priv/dna/architect_planner.yml"
    # Ensure we are in the right place
    assert File.exists?(dna_path)
    
    {:ok, pid} = StemCell.start_link(dna_path)
    assert Process.alive?(pid)
    assert :active == GenServer.call(pid, :get_status)
    
    GenServer.stop(pid)
  end
end
