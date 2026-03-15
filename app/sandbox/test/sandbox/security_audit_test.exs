defmodule Sandbox.SecurityAuditTest do
  use ExUnit.Case, async: true
  alias Sandbox.Provisioner

  test "verify_mount_safety prevents directory traversal" do
    jail_dir = Path.expand("~/.karyon/sandboxes")
    
    # Safe path
    safe_path = Path.join(jail_dir, "vm_1/data")
    assert {:ok, _} = Provisioner.verify_mount_safety(safe_path)
    
    # Unsafe path (outside jail)
    unsafe_path = "/etc/passwd"
    assert {:error, :unsafe_mount_path} = Provisioner.verify_mount_safety(unsafe_path)
    
    # Relative traversal attempt
    traversal_path = Path.join(jail_dir, "../../../etc/passwd")
    assert {:error, :unsafe_mount_path} = Provisioner.verify_mount_safety(traversal_path)
  end

  test "air-gapped networking mock validation" do
    # When KARYON_MOCK_HARDWARE is 1, it should skip real setup
    # We've already verified this in previous stabilization, 
    # but we'll add a structured test for it.
    System.put_env("KARYON_MOCK_HARDWARE", "1")
    # This shouldn't crash or attempt to run sudo
    assert :ok = Provisioner.setup_network("test-vm")
  end
end
