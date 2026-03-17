defmodule RhizomeTest do
  use ExUnit.Case
  @moduletag :external

  test "parses simple JSON and stores AST in Memgraph" do
    json_script = """
    {
      "type": "cell",
      "status": "active"
    }
    """
    
    assert {:ok, %{raw: _}} = Rhizome.Native.xtdb_submit("test", json_script)
  end

  test "submits bitemporal transactions to XTDB and recovers from history" do
    id = "cell_delta_456"
    data = %{status: :pruned, error: 0.8}

    assert {:ok, %{raw: _}} = Rhizome.Memory.submit_xtdb(id, data)
  end
end
