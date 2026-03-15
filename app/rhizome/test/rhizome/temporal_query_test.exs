defmodule Rhizome.TemporalQueryTest do
  use ExUnit.Case, async: false
  alias Rhizome.Native

  test "bitemporal state submission and retrieval" do
    id = "cell_123"
    data = %{"status" => "active", "energy" => 100}
    
    # 1. Submit initial state
    assert {:ok, _} = Native.xtdb_submit(id, Jason.encode!(data))
    
    # Wait for indexing
    Process.sleep(100)
    
    # 2. Query current state
    assert {:ok, [res]} = Native.xtdb_query("SELECT energy FROM xt.docs WHERE id = '#{id}'")
    assert res["energy"] == 100
    
    # 3. Submit updated state
    updated_data = %{"status" => "torpor", "energy" => 10}
    assert {:ok, _} = Native.xtdb_submit(id, Jason.encode!(updated_data))
    
    Process.sleep(100)
    
    # 4. Verify latest state
    assert {:ok, [res2]} = Native.xtdb_query("SELECT energy FROM xt.docs WHERE id = '#{id}'")
    assert res2["energy"] == 10
  end
end
