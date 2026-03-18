defmodule Rhizome.Property.MemoryConsistencyTest do
  use ExUnit.Case, async: false
  use ExUnitProperties
  alias Rhizome.Memory

  @moduledoc """
  Property-based tests for Rhizome dual-layer memory consistency.
  Validates that concurrent writes to XTDB and Memgraph remain eventually consistent.
  """

  @tag :external
  property "concurrent archive writes retain revision history and latest state" do
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
      results =
        data_points
        |> Task.async_stream(fn %{"id" => id, "value" => val} ->
          assert {:ok, %{raw: %{"xt/revision" => 1}}} =
                   Memory.write_archive_document(id, %{"val" => val, "phase" => "initial"})

          assert {:ok, %{raw: %{"xt/revision" => 2}}} =
                   Memory.write_archive_document(id, %{"val" => val + 1, "phase" => "updated"})

          {id, val}
        end)
        |> Enum.to_list()

      assert Enum.all?(results, fn {:ok, {_id, _val}} -> true end)

      unique_points = Enum.uniq_by(data_points, & &1["id"])

      Enum.each(unique_points, fn %{"id" => id, "value" => val} ->
        assert {:ok, [%{"val" => latest_val, "phase" => "updated", "xt/revision" => 2}]} =
                 Memory.query_archive(%{
                   "query" => %{
                     "find" => ["(pull ?e [val phase xt/revision])"],
                     "where" => [["?e", "xt/id", id]]
                   }
                 })

        assert latest_val == val + 1

        assert {:ok, history_rows} =
                 Memory.query_archive(%{
                   "query" => %{
                     "find" => ["(pull ?e [val phase xt/revision])"],
                     "where" => [["?e", "xt/id", id]]
                   },
                   "opts" => %{"history" => true}
                 })

        assert Enum.map(history_rows, & &1["xt/revision"]) == [1, 2]
      end)

      # 3. Cleanup
      Rhizome.Native.memgraph_query("MATCH (n) DETACH DELETE n")
    end
  end
end
