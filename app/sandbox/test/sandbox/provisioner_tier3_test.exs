defmodule Sandbox.ProvisionerTier3Test do
  use ExUnit.Case
  alias Sandbox.Provisioner

  test "Sandbox: Mount jail enforcement prevents path traversal" do
    base_sandbox_dir = Path.expand("~/.karyon/sandboxes")
    
    # Valid mounts
    valid_path = Path.join(base_sandbox_dir, "test_vm")
    assert {:ok, ^valid_path} = Provisioner.verify_mount_safety(valid_path)
    
    # Invalid mounts (Path Traversal)
    assert {:error, :unsafe_mount_path} == Provisioner.verify_mount_safety("/etc")
    assert {:error, :unsafe_mount_path} == Provisioner.verify_mount_safety("/home/adrian/.bashrc")
  end
end
