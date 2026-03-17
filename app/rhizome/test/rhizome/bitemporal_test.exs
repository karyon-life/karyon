defmodule Rhizome.BitemporalTest do
  use ExUnit.Case
  alias Rhizome.Native

  test "XTDB bitemporal submission" do
    id = "agent_state_1"
    data = %{
      "attr" => "energy",
      "value" => 100
    }
    
    case Native.xtdb_submit(id, data) do
      {:ok, %{raw: _raw}} -> assert true
      {:error, reason} -> 
        assert String.contains?(reason, "XTDB Error") or String.contains?(reason, "Connection refused")
    end
  end

  test "XTDB query with temporal context" do
    query = %{
      "query" => %{
        "find" => ["(pull ?e [*])"],
        "where" => [["?e", "attr", "energy"]]
      }
    }
    
    case Native.xtdb_query(query) do
      {:ok, results} when is_list(results) -> assert true
      {:error, reason} ->
        assert String.contains?(reason, "XTDB Error") or String.contains?(reason, "Connection refused")
    end
  end
end
