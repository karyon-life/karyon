defmodule Rhizome.TemporalQueryTest do
  use ExUnit.Case, async: false
  @moduletag :external
  alias Rhizome.Memory

  test "bitemporal state submission and retrieval" do
    id = "cell_mvcc_#{System.unique_integer([:positive, :monotonic])}_#{System.system_time(:microsecond)}"
    initial_valid_time = "2026-03-18T12:00:00Z"
    updated_valid_time = "2026-03-18T12:05:00Z"

    assert {:ok, %{raw: %{"xt/revision" => 1}}} =
             Memory.write_archive_document(id, %{
               "status" => "active",
               "energy" => 100,
               "xt/valid_time" => initial_valid_time
             })

    Process.sleep(10)

    assert {:ok, %{raw: %{"xt/revision" => 2}}} =
             Memory.write_archive_document(id, %{
               "status" => "torpor",
               "energy" => 10,
               "xt/valid_time" => updated_valid_time
             })

    assert {:ok, [%{"energy" => 10, "status" => "torpor", "xt/revision" => 2}]} =
             Memory.query_archive(%{
               "query" => %{
                 "find" => ["(pull ?e [energy status xt/revision])"],
                 "where" => [["?e", "xt/id", id]]
               }
             })

    assert {:ok, history_rows} =
             Memory.query_archive(%{
               "query" => %{
                 "find" => ["(pull ?e [energy status xt/revision xt/valid_time])"],
                 "where" => [["?e", "xt/id", id]]
               },
               "opts" => %{"history" => true}
             })

    assert Enum.map(history_rows, & &1["xt/revision"]) == [1, 2]

    assert {:ok, [%{"energy" => 100, "status" => "active", "xt/revision" => 1}]} =
             Memory.query_archive(%{
               "query" => %{
                 "find" => ["(pull ?e [energy status xt/revision])"],
                 "where" => [["?e", "xt/id", id]]
               },
               "opts" => %{"as_of" => "2026-03-18T12:02:00Z"}
             })
  end
end
