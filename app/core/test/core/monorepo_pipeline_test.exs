defmodule Core.MonorepoPipelineTest do
  use ExUnit.Case, async: true

  alias Sandbox.MonorepoPipeline

  test "validate_target_workspace/1 rejects engine-root workspaces" do
    assert {:error, :engine_workspace_forbidden} =
             MonorepoPipeline.validate_target_workspace(MonorepoPipeline.engine_root())
  end

  test "validate_target_workspace/1 accepts workspaces outside the engine tree" do
    workspace = Path.join(System.tmp_dir!(), "karyon-target-workspace-#{System.unique_integer([:positive])}")

    assert {:ok, ^workspace} = MonorepoPipeline.validate_target_workspace(workspace)
    assert MonorepoPipeline.workspace_role(workspace) == :target_workspace
  end

  test "target_workspace_from_intent/1 resolves workspace root from transition delta" do
    workspace = Path.join(System.tmp_dir!(), "karyon-target-workspace-#{System.unique_integer([:positive])}")

    assert MonorepoPipeline.target_workspace_from_intent(%{
             "transition_delta" => %{"workspace_root" => workspace}
           }) == workspace
  end
end
