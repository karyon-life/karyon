defmodule Sandbox.ProvisionerTest do
  use ExUnit.Case
  alias Sandbox.Provisioner

  describe "verify_mount_safety/1" do
    test "accepts paths within the sandbox jail" do
      base_dir = Path.expand("~/.karyon/sandboxes")
      safe_path = Path.join(base_dir, "my_vm/workspace")
      
      # Ensure the base dir exists for test (or mock Path.expand)
      # We just test the logic here
      assert {:ok, _} = Provisioner.verify_mount_safety(safe_path)
    end

    test "rejects paths outside the sandbox jail (Security Violation)" do
      unsafe_path = "/etc/passwd"
      assert {:error, :unsafe_mount_path} = Provisioner.verify_mount_safety(unsafe_path)
    end

    test "rejects relative paths that escape the jail" do
      unsafe_path = "~/.karyon/sandboxes/../.ssh/id_rsa"
      assert {:error, :unsafe_mount_path} = Provisioner.verify_mount_safety(unsafe_path)
    end
  end

  describe "network setup logic" do
    test "skips real setup when KARYON_MOCK_HARDWARE is 1" do
      System.put_env("KARYON_MOCK_HARDWARE", "1")
      # This test just verifies it doesn't crash or attempt real System.cmd
      assert {:ok, _} = Provisioner.provision_vm("any_plan")
    end
  end
end
