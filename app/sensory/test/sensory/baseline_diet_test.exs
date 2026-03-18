defmodule Sensory.BaselineDietTest do
  use ExUnit.Case, async: true

  defmodule NativeStub do
    def parse_to_graph(language, code) do
      Jason.encode!(%{
        "language" => language,
        "nodes" => [
          %{"id" => "root", "type" => "source_file", "text" => String.slice(code, 0, 12)},
          %{"id" => "fn", "type" => "function"}
        ],
        "edges" => [
          %{"source" => "root", "target" => "fn", "type" => "CONTAINS"}
        ]
      })
    end
  end

  defmodule MemoryStub do
    def upsert_graph_node(spec) do
      send(self(), {:upsert_graph_node, spec})
      {:ok, spec}
    end

    def relate_graph_nodes(spec) do
      send(self(), {:relate_graph_nodes, spec})
      {:ok, spec}
    end

    def submit_baseline_curriculum(spec) do
      send(self(), {:submit_baseline_curriculum, spec})
      {:ok, %{id: spec["baseline_id"]}}
    end
  end

  test "baseline diet ingestion establishes deterministic structural grammar and persists curriculum evidence" do
    repo = create_repo_fixture!()

    assert {:ok, baseline} =
             Sensory.BaselineDiet.ingest_repository(
               repo,
               native_module: NativeStub,
               memory_module: MemoryStub,
               acceptance_criteria: %{min_files: 3, min_languages: 3, min_total_nodes: 6}
             )

    assert baseline["acceptance"]["status"] == "accepted"
    assert baseline["file_count"] == 3
    assert baseline["language_count"] == 3
    assert baseline["total_nodes"] == 6
    assert baseline["languages"] == ["c", "elixir", "python"]
    assert_received {:submit_baseline_curriculum, persisted}
    assert persisted["baseline_id"] == baseline["baseline_id"]
  end

  test "baseline diet rejects repositories that fail the structural acceptance criteria" do
    repo = create_repo_fixture!()

    assert {:error, {:baseline_diet_rejected, baseline}} =
             Sensory.BaselineDiet.ingest_repository(
               repo,
               native_module: NativeStub,
               memory_module: MemoryStub,
               acceptance_criteria: %{min_files: 4, min_languages: 3, min_total_nodes: 6}
             )

    assert baseline["acceptance"]["status"] == "rejected"
    refute_received {:submit_baseline_curriculum, _persisted}
  end

  defp create_repo_fixture! do
    root = Path.join(System.tmp_dir!(), "sensory_baseline_repo_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "lib"))
    File.mkdir_p!(Path.join(root, "scripts"))
    File.mkdir_p!(Path.join(root, "src"))
    File.write!(Path.join(root, "lib/sample.ex"), "defmodule Sample do\n  def hi, do: :ok\nend\n")
    File.write!(Path.join(root, "scripts/sample.py"), "def hi():\n    return 'ok'\n")
    File.write!(Path.join(root, "src/main.c"), "int main() { return 0; }\n")

    on_exit(fn -> File.rm_rf(root) end)
    root
  end
end
