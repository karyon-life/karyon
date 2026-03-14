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

  test "parse_to_graph returns flat nodes and edges for javascript" do
    code = "let x = 10;"
    result = Sensory.Native.parse_to_graph("javascript", code)
    
    assert {:ok, data} = Jason.decode(result)
    assert is_list(data["nodes"])
    assert is_list(data["edges"])
    
    # Check if we have nodes
    assert length(data["nodes"]) > 0
    
    # Check if we have CHILD edges
    has_child_edge = Enum.any?(data["edges"], fn edge -> edge["type"] == "CHILD" end)
    assert has_child_edge
    
    # Verify a specific node text
    assert Enum.any?(data["nodes"], fn node -> node["text"] == "10" end)
  end

  test "parse_to_graph identifies import statements as dependencies" do
    code = """
    import { StemCell } from './core';
    let x = 10;
    """
    result = Sensory.Native.parse_to_graph("javascript", code)
    
    assert {:ok, data} = Jason.decode(result)
    
    # Verify that we have a dependency node
    has_dep = Enum.any?(data["nodes"], fn node -> 
      node["is_dependency"] == true && node["type"] == "import_statement"
    end)
    assert has_dep
  end

  test "parse_to_graph handles complex Python with imports" do
    code = """
    import os
    from core import StemCell
    
    def bootstrap():
        sc = StemCell()
        sc.ignite()
    """
    result = Sensory.Native.parse_to_graph("python", code)
    assert {:ok, data} = Jason.decode(result)
    
    # Identify import types in Python
    has_imports = Enum.any?(data["nodes"], fn node -> 
      node["is_dependency"] == true && (node["type"] == "import_statement" || node["type"] == "import_from_statement")
    end)
    assert has_imports
    
    # Verify we found the function definition
    assert Enum.any?(data["nodes"], fn node -> node["type"] == "function_definition" end)
  end

  test "parse_code returns unsupported for unknown language" do
    assert Sensory.Native.parse_code("fortran", "PROGRAM HELLO") == "Unsupported language"
  end
end
