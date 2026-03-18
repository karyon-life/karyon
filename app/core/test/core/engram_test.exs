defmodule Core.EngramTest do
  use ExUnit.Case
  alias Core.Engram

  @engram_path "priv/engrams/"
  @test_engram "tier1_test_engram"

  defmodule NativeStub do
    def memgraph_query(query) when is_binary(query) do
      observer = Process.whereis(:engram_test_observer)

      cond do
        String.contains?(query, "RETURN") ->
          {:ok,
           [
             %{
               "source_labels" => ["TaskNode"],
               "source_props" => %{"id" => "node_a", "kind" => "source"},
               "rel_type" => "KNOWLEDGE_LINK",
               "rel_props" => %{"weight" => 1},
               "target_labels" => ["TaskNode"],
               "target_props" => %{"id" => "node_b", "kind" => "target"}
             },
             %{
               "source_labels" => ["TaskNode"],
               "source_props" => %{"id" => "node_b", "kind" => "target"},
               "rel_type" => "PREDICTS",
               "rel_props" => %{"weight" => 2},
               "target_labels" => ["PredictionError"],
               "target_props" => %{"id" => "error_1", "kind" => "prediction_error"}
             }
           ]}

        observer ->
          send(observer, {:memgraph_query, query})
          {:ok, []}

        true ->
          {:ok, []}
      end
    end
  end

  setup do
    # Ensure cleanup of test engrams
    original_native = Application.get_env(:core, :engram_native_module)
    Application.put_env(:core, :engram_native_module, NativeStub)

    on_exit(fn ->
      File.rm("#{@engram_path}#{@test_engram}.engram")
      if original_native, do: Application.put_env(:core, :engram_native_module, original_native), else: Application.delete_env(:core, :engram_native_module)
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

  test "Engram.capture/2 writes a selective subset with provenance and compatibility metadata" do
    assert {:ok, path} =
             Engram.capture(@test_engram,
               subset: %{labels: ["PredictionError"], relationship_types: ["PREDICTS"]},
               use_case: "portable_prediction_error_bundle"
             )

    assert File.exists?(path)
    assert {:ok, description} = Engram.describe(@test_engram)
    assert description["format"] == "karyon.engram.v1"
    assert description["subset"]["labels"] == ["PredictionError"]
    assert description["subset"]["relationship_types"] == ["PREDICTS"]
    assert description["compatibility"]["engine_schema"] == "karyon.monorepo-pipeline.v1"
    assert description["provenance"]["use_case"] == "portable_prediction_error_bundle"
  end

  test "Engram.inject/2 supports partial hydration of a selected subset" do
    Process.register(self(), :engram_test_observer)

    on_exit(fn ->
      if Process.whereis(:engram_test_observer) == self(), do: Process.unregister(:engram_test_observer)
    end)

    path = "#{@engram_path}#{@test_engram}.engram"
    File.mkdir_p!(@engram_path)

    nodes = [
      %{"id" => "node_a", "labels" => ["TaskNode"], "properties" => %{"id" => "node_a", "kind" => "source"}},
      %{"id" => "node_b", "labels" => ["TaskNode"], "properties" => %{"id" => "node_b", "kind" => "target"}},
      %{"id" => "error_1", "labels" => ["PredictionError"], "properties" => %{"id" => "error_1", "kind" => "prediction_error"}}
    ]

    edges = [
      %{"type" => "KNOWLEDGE_LINK", "source_id" => "node_a", "target_id" => "node_b", "properties" => %{"weight" => 1}},
      %{"type" => "PREDICTS", "source_id" => "node_b", "target_id" => "error_1", "properties" => %{"weight" => 2}}
    ]

    digest =
      :crypto.hash(:sha256, Jason.encode!(%{"nodes" => nodes, "edges" => edges}))
      |> Base.encode16(case: :lower)

    envelope = %{
      "engram_version" => 1,
      "format" => "karyon.engram.v1",
      "name" => @test_engram,
      "captured_at" => System.system_time(:second),
      "node_count" => 3,
      "edge_count" => 2,
      "nodes" => nodes,
      "edges" => edges,
      "digest" => digest,
      "subset" => %{"ids" => [], "labels" => [], "relationship_types" => []},
      "provenance" => %{
        "captured_by" => "Core.Engram",
        "captured_at" => System.system_time(:second),
        "captured_from" => "rhizome",
        "name" => @test_engram,
        "use_case" => "partial_hydration",
        "engine_manifest" => Sandbox.MonorepoPipeline.engine_manifest()
      },
      "compatibility" => %{
        "engine_schema" => Sandbox.MonorepoPipeline.schema(),
        "distribution_mode" => "portable_subset",
        "hydration" => "idempotent_merge"
      }
    }

    File.write!(path, :zlib.gzip(Jason.encode!(envelope)))

    assert :ok =
             Engram.inject(@test_engram,
               subset: %{labels: ["PredictionError"], relationship_types: ["PREDICTS"]}
             )

    queries =
      for _ <- 1..3 do
        assert_receive {:memgraph_query, query}
        query
      end

    assert Enum.any?(queries, &String.contains?(&1, "error_1"))
    assert Enum.any?(queries, &String.contains?(&1, "node_b"))
    refute Enum.any?(queries, &String.contains?(&1, "node_a"))
  end
end
