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
end
