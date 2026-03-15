defmodule Sensory.NifTest do
  use ExUnit.Case
  alias Sensory.Native

  test "ingest_to_memgraph returns ResourceArc" do
    code = "const x = 10;"
    # This might fail if Memgraph isn't running, but we check the return type handling
    case Native.ingest_to_memgraph("javascript", code) do
      {:ok, resource} -> 
        assert is_reference(resource)
      {:error, reason} ->
        assert String.contains?(reason, "Connection Error")
    end
  end

  test "parse_code returns JSON string" do
    code = "const x = 10;"
    result = Native.parse_code("javascript", code)
    assert {:ok, _} = Jason.decode(result)
  end
end
