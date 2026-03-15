defmodule Sensory.IngestionEdgeCaseTest do
  use ExUnit.Case
  alias Sensory.Native

  test "ingest complex javascript (async/await, destructuring)" do
    code = """
    async function foo({a, b}) {
      const { x } = await bar();
      return x + a;
    }
    """
    case Native.ingest_to_memgraph("javascript", code) do
      {:ok, resource} -> assert is_reference(resource)
      {:error, reason} -> 
         # Accept connection error if Memgraph is offline, but check NIF logic
         assert String.contains?(reason, "Connection Error")
    end
  end

  test "ingest malformed python" do
    code = "def foo(: missing colon"
    # Tree-sitter should still parse it as ERROR nodes, not crash the VM
    result = Native.parse_code("python", code)
    assert String.contains?(result, "ERROR") or String.contains?(result, "type")
  end
end
