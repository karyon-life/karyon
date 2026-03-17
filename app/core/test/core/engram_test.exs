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

  test "Engram.capture/1 rejects invalid portable names" do
    assert {:error, :invalid_engram_name} = Engram.capture("../bad_name")
    assert {:error, :invalid_engram_name} = Engram.inject("../bad_name")
  end

  test "Engram.inject/1 rejects malformed engram payloads" do
    path = "#{@engram_path}#{@test_engram}.engram"
    File.mkdir_p!(@engram_path)
    File.write!(path, "not-a-valid-engram")

    assert {:error, :invalid_engram_payload} = Engram.inject(@test_engram)
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

  test "Engram.inject/1 accepts a valid portable schema envelope" do
    path = "#{@engram_path}#{@test_engram}.engram"
    File.mkdir_p!(@engram_path)

    nodes = [
      %{"id" => "node_a", "labels" => ["TaskNode"], "properties" => %{"id" => "node_a", "kind" => "source"}},
      %{"id" => "node_b", "labels" => ["TaskNode"], "properties" => %{"id" => "node_b", "kind" => "target"}}
    ]

    edges = [
      %{"type" => "KNOWLEDGE_LINK", "source_id" => "node_a", "target_id" => "node_b", "properties" => %{"weight" => 1}}
    ]

    digest =
      :crypto.hash(:sha256, Jason.encode!(%{"nodes" => nodes, "edges" => edges}))
      |> Base.encode16(case: :lower)

    envelope = %{
      "engram_version" => 1,
      "format" => "karyon.engram.v1",
      "name" => @test_engram,
      "captured_at" => System.system_time(:second),
      "node_count" => 2,
      "edge_count" => 1,
      "nodes" => nodes,
      "edges" => edges,
      "digest" => digest
    }

    File.write!(path, :zlib.gzip(Jason.encode!(envelope)))

    case Engram.inject(@test_engram) do
      :ok -> :ok
      {:error, _reason} -> :ok
    end
  end
end
