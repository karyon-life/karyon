defmodule Sandbox.FirecrackerTest do
  use ExUnit.Case, async: false

  # Since we don't have a real Firecracker socket in the CI/Test environment, 
  # we verify the protocol formatting and internal error handling.

  test "init_vmm attempts to connect to socket" do
    original_mock = System.get_env("KARYON_MOCK_HARDWARE")
    System.put_env("KARYON_MOCK_HARDWARE", "0")

    on_exit(fn ->
      if original_mock do
        System.put_env("KARYON_MOCK_HARDWARE", original_mock)
      else
        System.delete_env("KARYON_MOCK_HARDWARE")
      end
    end)

    assert {:error, :socket_not_found} == Sandbox.Firecracker.init_vmm("/tmp/non_existent.socket")
  end

  test "set_drive expansion and body formatting" do
    rootfs = Sandbox.Firecracker.drive_request("rootfs", "../tmp/rootfs.ext4")
    workspace = Sandbox.Firecracker.drive_request("workspace", "../tmp/workspace.ext4", root_device: false, read_only: false)

    assert rootfs.drive_id == "rootfs"
    assert rootfs.is_root_device == true
    assert rootfs.is_read_only == true
    assert Path.type(rootfs.path_on_host) == :absolute

    assert workspace.drive_id == "workspace"
    assert workspace.is_root_device == false
    assert workspace.is_read_only == false
    assert Path.type(workspace.path_on_host) == :absolute
  end

  test "boot_requirements fails closed when firecracker prerequisites are missing" do
    original_binary = Application.get_env(:sandbox, :firecracker_binary)
    original_kernel = Application.get_env(:sandbox, :kernel_image_path)
    original_rootfs = Application.get_env(:sandbox, :rootfs_path)

    Application.delete_env(:sandbox, :firecracker_binary)
    Application.delete_env(:sandbox, :kernel_image_path)
    Application.delete_env(:sandbox, :rootfs_path)
    System.delete_env("KARYON_FIRECRACKER_BINARY")
    System.delete_env("KARYON_FIRECRACKER_KERNEL")
    System.delete_env("KARYON_FIRECRACKER_ROOTFS")

    on_exit(fn ->
      restore_env(:sandbox, :firecracker_binary, original_binary)
      restore_env(:sandbox, :kernel_image_path, original_kernel)
      restore_env(:sandbox, :rootfs_path, original_rootfs)
    end)

    assert {:error, reason} = Sandbox.Firecracker.boot_requirements()
    assert reason in [:firecracker_binary_not_found, :kernel_image_not_found, :rootfs_image_not_found]
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
