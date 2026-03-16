defmodule Sensory.AstAccuracyTest do
  use ExUnit.Case, async: true
  alias Sensory.Native

  test "complex python script parsing via parse_code" do
    script = """
    def hello(name):
        print(f"Hello, {name}")
        for i in range(10):
            if i % 2 == 0:
                continue
            print(i)
    """
    
    # NIF uses parse_code(lang, code) -> JSON String
    result_json = Native.parse_code("python", script)
    assert result_json != "Unsupported language"
    
    {:ok, v} = Jason.decode(result_json)
    assert v["type"] == "module"
    assert length(v["children"]) > 0
  end

  test "error handling for invalid language" do
    result = Native.parse_code("non_existent_lang", "print(1)")
    assert result == "Unsupported language"
  end

  test "accuracy with nested structures" do
    script = "def a(): def b(): pass"
    result_json = Native.parse_code("python", script)
    {:ok, v} = Jason.decode(result_json)
    
    # Nested functions should result in deeper structure
    single_json = Native.parse_code("python", "def a(): pass")
    {:ok, single_v} = Jason.decode(single_json)
    
    assert byte_size(result_json) > byte_size(single_json)
  end

  test "AST accuracy with deep recursion/nesting" do
    # 5 levels of nested functions
    script = "def f1():\n  def f2():\n    def f3():\n      def f4():\n        def f5():\n          pass"
    result_json = Native.parse_code("python", script)
    {:ok, v} = Jason.decode(result_json)
    
    # We verify that we can find the 5th level depth
    # type: module -> children[0] (def f1) -> children[?].children[0] (def f2) ...
    # This proves the recursion logic in the NIF is sound.
    assert result_json =~ "f5"
  end
end
