defmodule Core.MonorepoPipelineTest do
  use ExUnit.Case, async: true

  alias Core.EnvironmentMembrane

  test "validate_target_workspace/1 rejects engine-root workspaces" do
    assert {:error, :engine_workspace_forbidden} =
             EnvironmentMembrane.validate_target_workspace(EnvironmentMembrane.engine_root())
  end

  test "validate_target_workspace/1 accepts workspaces outside the engine tree" do
    workspace = Path.join(System.tmp_dir!(), "karyon-target-workspace-#{System.unique_integer([:positive])}")

    assert {:ok, ^workspace} = EnvironmentMembrane.validate_target_workspace(workspace)
    assert EnvironmentMembrane.workspace_role(workspace) == :target_workspace
  end

  test "target_workspace_from_intent/1 resolves workspace root from transition delta" do
    workspace = Path.join(System.tmp_dir!(), "karyon-target-workspace-#{System.unique_integer([:positive])}")

    assert EnvironmentMembrane.target_workspace_from_intent(%{
             "transition_delta" => %{"workspace_root" => workspace}
           }) == workspace
  end
end
