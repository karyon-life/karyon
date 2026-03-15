defmodule Sensory.AstAccuracyTest do
  use ExUnit.Case, async: true
  alias Sensory.Native

  test "complex python script parsing" do
    script = """
    def hello(name):
        print(f"Hello, {name}")
        for i in range(10):
            if i % 2 == 0:
                continue
            print(i)
    """
    
    # Verify it parses without error and returns matching node count
    # Sensory.Native.parse_script returns {:ok, %{node_count: N}}
    assert {:ok, result} = Native.parse_script(script, "python")
    assert result.node_count > 10
  end

  test "error handling for invalid language" do
    assert {:error, :unsupported_language} = Native.parse_script("print(1)", "non_existent_lang")
  end

  test "accuracy with nested structures" do
    script = "def a(): def b(): pass"
    assert {:ok, result} = Native.parse_script(script, "python")
    # Nested functions should result in more nodes than a single function
    {:ok, single} = Native.parse_script("def a(): pass", "python")
    assert result.node_count > single.node_count
  end
end
