defmodule Sandbox.SecurityAuditTest do
  use ExUnit.Case, async: false
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
    # This shouldn't crash or attempt to run sudo
    original_mock = System.get_env("KARYON_MOCK_HARDWARE")
    System.put_env("KARYON_MOCK_HARDWARE", "1")

    on_exit(fn ->
      if original_mock do
        System.put_env("KARYON_MOCK_HARDWARE", original_mock)
      else
        System.delete_env("KARYON_MOCK_HARDWARE")
      end
    end)

    assert :ok = Provisioner.setup_network("test-vm")
  end

  test "verify_network failure handling" do
    # Ensure helper path check doesn't crash if binary is missing or perms are wrong
    # but more importantly, verify the error return when real check fails (or mock isn't 1)
    System.put_env("KARYON_MOCK_HARDWARE", "0")
    # This will likely fail in CI due to missing tap or permissions
    # We just want to ensure it returns an error tuple and doesn't crash the BEAM
    result = Provisioner.verify_network("non-existent-tap")
    assert {:error, _} = result
    
    # Reset mock for other tests
    System.put_env("KARYON_MOCK_HARDWARE", "1")
  end
end
