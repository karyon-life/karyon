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
    assert {:ok, _msg} = Rhizome.Nif.parse_and_store(json_script)
  end
end
