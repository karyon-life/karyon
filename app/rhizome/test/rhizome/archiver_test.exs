defmodule Rhizome.ArchiverTest do
  use ExUnit.Case
  alias Rhizome.Native

  test "bridge_to_xtdb executes without crashing" do
    # Even if XTDB/Memgraph are down, the NIF should return an error tuple, not crash
    case Native.bridge_to_xtdb() do
      {:ok, %{message: info}} -> assert String.contains?(info, "Successfully bridged")
      {:error, reason} -> 
        assert String.contains?(reason, "Memgraph Query Error") or 
               String.contains?(reason, "Connection Error") or
               String.contains?(reason, "XTDB Error")
    end
  end

  test "optimizer logic runs Louvain grammar community detection" do
    case Native.optimize_graph() do
      {:ok, info} -> 
        assert String.contains?(info, "Louvain optimization complete") or 
               String.contains?(info, "No operator pooled-sequence graph data")
      {:error, reason} ->
        assert String.contains?(reason, "Memgraph client not initialized") or
               String.contains?(reason, "Connection Error") or
               String.contains?(reason, "Query Error")
    end
  end
end
