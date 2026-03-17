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

    test "rejects sibling paths that only share the sandbox prefix" do
      unsafe_path = Path.expand("~/.karyon/sandboxes_evil/vm/workspace")
      assert {:error, :unsafe_mount_path} = Provisioner.verify_mount_safety(unsafe_path)
    end

    test "rejects symlink mount targets inside the jail" do
      base_dir = Path.expand("~/.karyon/sandboxes")
      File.mkdir_p!(base_dir)

      link_path = Path.join(base_dir, "vm_symlink")
      File.rm_rf(link_path)
      File.ln_s!("/etc", link_path)

      on_exit(fn ->
        File.rm(link_path)
      end)

      assert {:error, :unsafe_mount_path} = Provisioner.verify_mount_isolation(link_path)
    end
  end

  describe "network setup logic" do
    test "resolves helper path from explicit sandbox config" do
      tmp_dir = System.tmp_dir!()
      helper_path = Path.join(tmp_dir, "karyon-net-helper-test")

      File.write!(helper_path, "#!/bin/sh\nexit 0\n")
      File.chmod!(helper_path, 0o755)

      original = Application.get_env(:sandbox, :net_helper_path)
      Application.put_env(:sandbox, :net_helper_path, helper_path)

      on_exit(fn ->
        if original do
          Application.put_env(:sandbox, :net_helper_path, original)
        else
          Application.delete_env(:sandbox, :net_helper_path)
        end

        File.rm(helper_path)
      end)

      assert {:ok, ^helper_path} = Provisioner.helper_path()
    end

    test "skips real setup when KARYON_MOCK_HARDWARE is 1" do
      System.put_env("KARYON_MOCK_HARDWARE", "1")
      # This test just verifies it doesn't crash or attempt real System.cmd
      assert {:ok, _} = Provisioner.provision_vm("any_plan")
    end
  end

  describe "capture_output/1" do
    test "returns persisted runtime telemetry for a real VM" do
      stdout_path = Path.join(System.tmp_dir!(), "sandbox-capture-stdout")
      stderr_path = Path.join(System.tmp_dir!(), "sandbox-capture-stderr")
      vm_id = "vm-capture"
      original_mock = System.get_env("KARYON_MOCK_HARDWARE")

      System.put_env("KARYON_MOCK_HARDWARE", "0")
      File.write!(stdout_path, "program output\n")
      File.write!(stderr_path, "warning output\n")

      Sandbox.RuntimeRegistry.put(vm_id, %{
        stdout_path: stdout_path,
        stderr_path: stderr_path,
        exit_code: 17,
        status: :exited,
        pain_reported: true
      })

      on_exit(fn ->
        if original_mock do
          System.put_env("KARYON_MOCK_HARDWARE", original_mock)
        else
          System.delete_env("KARYON_MOCK_HARDWARE")
        end

        File.rm(stdout_path)
        File.rm(stderr_path)
      end)

      assert {:ok, result} = Provisioner.capture_output(vm_id)
      assert result.stdout == "program output\n"
      assert result.stderr == "warning output\n"
      assert result.exit_code == 17
      assert result.status == :exited
      assert result.mode == :firecracker
      assert result.vm_id == vm_id
    end

    test "returns an error when runtime telemetry does not exist" do
      original_mock = System.get_env("KARYON_MOCK_HARDWARE")
      System.put_env("KARYON_MOCK_HARDWARE", "0")

      on_exit(fn ->
        if original_mock do
          System.put_env("KARYON_MOCK_HARDWARE", original_mock)
        else
          System.delete_env("KARYON_MOCK_HARDWARE")
        end
      end)

      assert {:error, :vm_runtime_not_found} = Provisioner.capture_output("vm-missing")
    end
  end

  describe "privilege boundary" do
    test "VMM cleanup delegates tap teardown to configured helper" do
      tmp_dir = System.tmp_dir!()
      helper_path = Path.join(tmp_dir, "karyon-net-helper-cleanup-test")
      marker_path = Path.join(tmp_dir, "karyon-net-helper-cleanup-marker")

      File.write!(
        helper_path,
        "#!/bin/sh\nprintf '%s %s' \"$1\" \"$2\" > \"$KARYON_HELPER_MARKER\"\nexit 0\n"
      )

      File.chmod!(helper_path, 0o755)

      original_helper = Application.get_env(:sandbox, :net_helper_path)
      original_mock = System.get_env("KARYON_MOCK_HARDWARE")
      original_marker = System.get_env("KARYON_HELPER_MARKER")

      Application.put_env(:sandbox, :net_helper_path, helper_path)
      System.put_env("KARYON_MOCK_HARDWARE", "0")
      System.put_env("KARYON_HELPER_MARKER", marker_path)

      on_exit(fn ->
        if original_helper do
          Application.put_env(:sandbox, :net_helper_path, original_helper)
        else
          Application.delete_env(:sandbox, :net_helper_path)
        end

        if original_mock do
          System.put_env("KARYON_MOCK_HARDWARE", original_mock)
        else
          System.delete_env("KARYON_MOCK_HARDWARE")
        end

        if original_marker do
          System.put_env("KARYON_HELPER_MARKER", original_marker)
        else
          System.delete_env("KARYON_HELPER_MARKER")
        end

        File.rm(helper_path)
        File.rm(marker_path)
      end)

      assert :ok = Sandbox.VmmSupervisor.cleanup_resources("vm-cleanup", "/tmp/non-existent.socket")
      assert File.read!(marker_path) == "cleanup tap-vm-cleanup"
    end
  end
end
