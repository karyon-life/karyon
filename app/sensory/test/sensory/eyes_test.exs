defmodule Sensory.EyesTest do
  use ExUnit.Case, async: true

  defmodule NativeStub do
    def parse_to_graph(language, code) do
      Jason.encode!(%{
        "language" => language,
        "nodes" => [
          %{"id" => "root", "type" => "source_file", "text" => String.slice(code, 0, 12)}
        ],
        "edges" => []
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
  end

  test "repository parsing is deterministic across repeated runs" do
    repo = create_repo_fixture!()

    assert {:ok, first} = Sensory.Eyes.parse_repository(repo, native_module: NativeStub)
    assert {:ok, second} = Sensory.Eyes.parse_repository(repo, native_module: NativeStub)

    assert first == second
    assert Enum.map(first.files, & &1.path) == ["lib/sample.ex", "scripts/sample.py", "src/main.c"]
  end

  test "repository projection persists typed topology into rhizome" do
    repo = create_repo_fixture!()

    assert {:ok, repository} =
             Sensory.Eyes.project_repository(
               repo,
               native_module: NativeStub,
               memory_module: MemoryStub
             )

    assert repository.file_count == 3
    assert_received {:upsert_graph_node, %{label: "Repository"}}
    assert_received {:relate_graph_nodes, %{relationship_type: "CONTAINS_FILE"}}
    assert_received {:upsert_graph_node, %{label: "AstProjection"}}
    assert_received {:relate_graph_nodes, %{relationship_type: "PARSED_AS"}}
  end

  defp create_repo_fixture! do
    root = Path.join(System.tmp_dir!(), "sensory_eyes_repo_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "lib"))
    File.mkdir_p!(Path.join(root, "scripts"))
    File.mkdir_p!(Path.join(root, "src"))
    File.write!(Path.join(root, "lib/sample.ex"), "defmodule Sample do\n  def hi, do: :ok\nend\n")
    File.write!(Path.join(root, "scripts/sample.py"), "def hi():\n    return 'ok'\n")
    File.write!(Path.join(root, "src/main.c"), "int main() { return 0; }\n")
    File.write!(Path.join(root, "README.md"), "# ignored\n")

    on_exit(fn -> File.rm_rf(root) end)
    root
  end
end
