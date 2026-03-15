defmodule Sensory.PerceptionFidelityTest do
  use ExUnit.Case, async: true
  alias Sensory.Native

  @js_code """
  import { x } from 'mod';
  function test(a) {
    return a + x;
  }
  export default test;
  """

  @python_code """
  def hello(name):
      return f"Hello, {name}"
  """

  @c_code """
  #include <stdio.h>
  int main() {
      printf("Hello World\\n");
      return 0;
  }
  """

  test "verifies javascript perception fidelity and dependency detection" do
    result = Native.parse_to_graph("javascript", @js_code)
    {:ok, graph} = Jason.decode(result)
    
    nodes = graph["nodes"]
    edges = graph["edges"]

    assert length(nodes) > 10
    assert length(edges) > 10

    # Verify dependency tokens are marked
    dependencies = Enum.filter(nodes, fn n -> n["is_dependency"] == true end)
    assert length(dependencies) >= 2 # import and export
    
    texts = Enum.map(dependencies, & &1["text"])
    assert Enum.any?(texts, fn t -> String.contains?(t, "import") end)
    assert Enum.any?(texts, fn t -> String.contains?(t, "export") end)
  end

  test "verifies python perception fidelity" do
    result = Native.parse_to_graph("python", @python_code)
    {:ok, graph} = Jason.decode(result)
    
    assert graph["nodes"] |> length() > 5
    assert Enum.any?(graph["nodes"], fn n -> n["type"] == "function_definition" end)
  end

  test "verifies C perception fidelity" do
    result = Native.parse_to_graph("c", @c_code)
    {:ok, graph} = Jason.decode(result)
    
    assert graph["nodes"] |> length() > 5
    assert Enum.any?(graph["nodes"], fn n -> n["type"] == "function_definition" end)
  end

  test "handles unsupported languages gracefully" do
    result = Native.parse_code("cobol", "MOVE 1 TO X")
    assert result == "Unsupported language"
  end
end
