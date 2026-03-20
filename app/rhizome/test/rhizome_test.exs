defmodule RhizomeTest do
  use ExUnit.Case
  @moduletag :external

  test "submits raw JSON documents into the temporal archive transport" do
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

  test "persists execution outcomes into XTDB memory" do
    outcome = %{
      "cell_id" => "planner_cell",
      "action" => "emit_babble",
      "executor" => "Core.OperatorSandboxExecutor.execute_plan",
      "status" => "success",
      "vm_id" => "operator_environment",
      "exit_code" => 0,
      "result" => %{"stdout" => "ok", "stderr" => ""}
    }

    assert {:ok, %{id: id}} = Rhizome.Memory.submit_execution_outcome(outcome)

    assert {:ok, rows} =
             Rhizome.Native.xtdb_query(%{
               "query" => %{
                 "find" => ["(pull ?e [cell_id action status vm_id exit_code])"],
                 "where" => [["?e", "xt/id", id]]
               }
             })

    assert [%{"cell_id" => "planner_cell", "action" => "emit_babble", "status" => "success",
              "vm_id" => "operator_environment", "exit_code" => 0}] = rows
  end
end
