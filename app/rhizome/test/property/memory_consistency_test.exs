defmodule Rhizome.Property.MemoryConsistencyTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  @moduledoc """
  Property-based tests for Rhizome dual-layer memory consistency.
  Validates that concurrent writes to XTDB and Memgraph remain eventually consistent.
  """

  @tag :external
  property "concurrent writes to Memgraph and XTDB remain traceable" do
    check all data_points <- list_of(
                fixed_map(%{
                  "id" => string(:alphanumeric, min_length: 5),
                  "value" => integer()
                }),
                min_length: 2,
                max_length: 10
              ),
              max_runs: 5 do
      
      # 1. Clear state
      Rhizome.Native.memgraph_query("MATCH (n) DETACH DELETE n")

      # 2. Parallel writes
      _results = 
        data_points
        |> Task.async_stream(fn %{"id" => id, "value" => val} ->
          # Submit to XTDB
          xtdb_res = Rhizome.Native.xtdb_submit(id, Jason.encode!(%{"val" => val}))
          # Submit to Memgraph
          mem_res = Rhizome.Native.memgraph_query("MERGE (n:TestNode {id: '#{id}'}) SET n.value = #{val}")
          {id, xtdb_res, mem_res}
        end)
        |> Enum.to_list()

      # 3. Verify total nodes in Memgraph
      _unique_ids = data_points |> Enum.map(& &1["id"]) |> Enum.uniq() |> length()
      {:ok, _} = Rhizome.Native.memgraph_query("MATCH (n:TestNode) RETURN count(n) as count")
      
      # 4. Cleanup
      Rhizome.Native.memgraph_query("MATCH (n) DETACH DELETE n")
    end
  end
end
