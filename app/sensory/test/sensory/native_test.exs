defmodule Sensory.NativeTest do
  use ExUnit.Case, async: true

  test "parse_code returns serialized JSON AST for javascript" do
    code = "let x = 10;"
    result = Sensory.Native.parse_code("javascript", code)
    
    # Verify it is valid JSON
    assert {:ok, data} = Jason.decode(result)
    assert data["type"] == "program"
    assert is_list(data["children"])
    
    # Verify we can find the variable declaration
    found_let = Enum.any?(data["children"], fn child -> 
      child["type"] == "lexical_declaration" || child["text"] =~ "let"
    end)
    assert found_let
  end

  test "parse_code returns unsupported for unknown language" do
    assert Sensory.Native.parse_code("fortran", "PROGRAM HELLO") == "Unsupported language"
  end
end
