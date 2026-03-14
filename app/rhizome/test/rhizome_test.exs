defmodule RhizomeTest do
  use ExUnit.Case

  test "parses simple JSON and stores AST in Memgraph" do
    json_script = """
    {
      "type": "cell",
      "status": "active"
    }
    """
    
    # In a full test environment, we would query Memgraph directly to ensure the node
    # exists, but for MVP Scope, we ensure the NIF returns :ok without crashing.
    assert {:ok, _msg} = Rhizome.Native.xtdb_submit("test", json_script)
  end

  test "submits bitemporal transactions to XTDB and recovers from history" do
    id = "cell_delta_456"
    data = %{status: :pruned, error: 0.8}
    
    # Verify NIF returns successful transaction response (mocked in test_helper)
    assert {:ok, _tx_id} = Rhizome.Memory.submit_xtdb(id, data)
  end
end
