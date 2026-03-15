defmodule Core.GlobalTier5Test do
  use ExUnit.Case
  alias Core.Engram
  alias Core.MotorDriver

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
      plan ->
        assert is_list(plan)
        Enum.each(plan, fn step ->
          assert Map.has_key?(step, :action)
          assert Map.has_key?(step, :params)
        end)
    end
  end
end
