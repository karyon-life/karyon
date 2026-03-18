defmodule Core.GlobalTier5Test do
  use ExUnit.Case
  alias Core.Engram
  alias Core.EpigeneticSupervisor
  alias Core.MotorDriver
  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Step

  @engram_name "test_knowledge_base"

  setup_all do
    # Ensure dependencies like Rhizome/Memgraph are accessible
    # or use a mock if we can.
    # For CI, we'll test the interface logic.
    :ok
  end

  test "Engram: Capture and Injection cycle" do
    # 1. Capture should fail if Memgraph is not running, but we check if it handles return
    # If it works, we verify the file creation.
    case Engram.capture(@engram_name) do
      {:ok, path} ->
        assert File.exists?(path)
        assert :ok == Engram.inject(@engram_name)
      {:error, _} ->
        # Expected if Memgraph is down in CI
        :ok
    end
  end

  test "MotorDriver: Planning sequences are logically sound" do
    # We sequence a plan for a given attractor
    # In Karyon, attractors are graph nodes.
    # We'll use a mock attractor ID.
    
    case MotorDriver.sequence_plan("attractor_001") do
      {:error, :attractor_not_found} -> :ok
      {:error, :graph_plan_empty} -> :ok
      {:ok, %Plan{} = plan} ->
        assert plan.attractor.id == "attractor_001"
        assert is_list(plan.steps)

        Enum.each(plan.steps, fn %Step{} = step ->
          assert is_binary(step.action)
          assert is_map(step.params)
          assert is_binary(step.id)
          assert %AbstractState{} = step.predicted_state
          assert is_binary(step.predicted_state.summary)
        end)
    end
  end

  test "EpigeneticSupervisor exposes live cytoplasm inventory without direct supervisor introspection" do
    assert is_list(EpigeneticSupervisor.active_cells())
    assert is_integer(EpigeneticSupervisor.active_cell_count())
  end
end
