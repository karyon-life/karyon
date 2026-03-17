defmodule Rhizome.TemporalQueryTest do
  use ExUnit.Case, async: false
  @moduletag :external
  alias Rhizome.Native

  test "bitemporal state submission and retrieval" do
    id = "cell_123"
    data = %{"status" => "active", "energy" => 100}
    query = %{
      "query" => %{
        "find" => ["(pull ?e [energy])"],
        "where" => [["?e", "xt/id", id]]
      }
    }
    
    # 1. Submit initial state
    assert {:ok, _} = Native.xtdb_submit(id, data)

    # Wait for indexing
    Process.sleep(100)

    # 2. Query current state
    assert {:ok, rows} = Native.xtdb_query(query)
    assert is_list(rows)

    # 3. Submit updated state
    updated_data = %{"status" => "torpor", "energy" => 10}
    assert {:ok, _} = Native.xtdb_submit(id, updated_data)

    Process.sleep(100)

    # 4. Verify latest state
    assert {:ok, rows2} = Native.xtdb_query(query)
    assert is_list(rows2)
  end
end
