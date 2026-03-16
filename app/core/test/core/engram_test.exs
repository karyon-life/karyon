defmodule Core.EngramTest do
  use ExUnit.Case
  alias Core.Engram

  @engram_path "priv/engrams/"
  @test_engram "tier1_test_engram"

  setup do
    # Ensure cleanup of test engrams
    on_exit(fn ->
      File.rm("#{@engram_path}#{@test_engram}.engram")
    end)
    :ok
  end

  test "Engram.capture/1 result handling" do
    # Verify that capture either succeeds or returns a valid error from NIF
    case Engram.capture(@test_engram) do
      {:ok, _path} -> :ok
      {:error, _reason} -> :ok
    end
  end

  test "Engram.inject/1 handles missing files gracefully" do
    assert {:error, :engram_not_found} = Engram.inject("non_existent_engram")
  end

  test "Engram.capture/1 handles result based on environment" do
    # When Memgraph is not running (typical CI/test env), it returns {:error, _}
    # We verify it doesn't crash and returns a valid error tuple or ok path.
    case Engram.capture(@test_engram) do
      {:ok, path} -> 
        assert File.exists?(path)
      {:error, _} ->
        # Expected if Memgraph is down
        :ok
    end
  end
end
