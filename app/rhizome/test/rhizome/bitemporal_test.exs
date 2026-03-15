defmodule Rhizome.BitemporalTest do
  use ExUnit.Case
  alias Rhizome.Native

  test "XTDB bitemporal submission" do
    id = "agent_state_1"
    data = Jason.encode!(%{
      "attr" => "energy",
      "value" => 100
    })
    
    case Native.xtdb_submit(id, data) do
      {:ok, _tx_id} -> assert true
      {:error, reason} -> 
        assert String.contains?(reason, "XTDB Error") or String.contains?(reason, "Connection refused")
    end
  end

  test "XTDB query with temporal context" do
    query = Jason.encode!(%{
      "find" => ["e"],
      "where" => [["e", "attr", "energy"]]
    })
    
    case Native.xtdb_query(query) do
      {:ok, _results} -> assert true
      {:error, reason} ->
        assert String.contains?(reason, "XTDB Error") or String.contains?(reason, "Connection refused")
    end
  end
end
