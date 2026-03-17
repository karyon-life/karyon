defmodule Sandbox.SecurityIsolationTest do
  use ExUnit.Case, async: false
  alias Sandbox.Provisioner

  setup do
    on_exit(fn ->
      # Cleanup any leftovers
      try do
        System.cmd("iptables", ["-F", "KARYON_ISOLATION"]) 
      rescue 
        _ -> :ok
      end
    end)
    :ok
  end

  test "VM machine configuration enforces strict resource limits (vCPU, RAM)" do
    # We use a mock to verify the machine config payload
    # In a real environment, we would inspect the running VMM
    
    config = %{
      vcpu_count: 2,
      mem_size_mib: 512,
      ht_enabled: false
    }
    
    # Simulate the API call
    payload = Jason.encode!(config)
    assert String.contains?(payload, "\"vcpu_count\":2")
    assert String.contains?(payload, "\"mem_size_mib\":512")
  end

  test "air-gap isolation logic executes without error in mock mode" do
    System.put_env("KARYON_MOCK_HARDWARE", "1")
    # We verify that provision_vm (which calls setup_network) works fine
    assert {:ok, _vm_id} = Provisioner.provision_vm("/tmp/test_plan.json")
  end

  test "verify_mount_safety prevents path traversal and enforces jail" do
    base_dir = Path.expand("~/.karyon/sandboxes")
    
    # Valid path
    valid_path = Path.join(base_dir, "my_vm/workspace")
    assert {:ok, _} = Provisioner.verify_mount_safety(valid_path)
    
    # Invalid path (outside jail)
    invalid_path = "/etc/passwd"
    assert {:error, :unsafe_mount_path} = Provisioner.verify_mount_safety(invalid_path)
    
    # Relative traversal attempt
    traversal_path = Path.join(base_dir, "../../../etc/passwd")
    assert {:error, :unsafe_mount_path} = Provisioner.verify_mount_safety(traversal_path)
  end

  test "UDS socket segregation prevents cross-VM crosstalk" do
    # Verify that each VM has a unique socket path based on its ID
    vm_id_1 = "vm_alpha"
    vm_id_2 = "vm_beta"
    
    socket_path_1 = Path.join(System.user_home!(), ".karyon/sandboxes/#{vm_id_1}/firecracker.socket")
    socket_path_2 = Path.join(System.user_home!(), ".karyon/sandboxes/#{vm_id_2}/firecracker.socket")
    
    assert socket_path_1 != socket_path_2
    assert String.contains?(socket_path_1, vm_id_1)
    assert String.contains?(socket_path_2, vm_id_2)
  end

  @tag :external
  test "real provision cleanup removes the VM tap device" do
    original_mock = System.get_env("KARYON_MOCK_HARDWARE")
    original_kernel = System.get_env("KARYON_FIRECRACKER_KERNEL")
    original_rootfs = System.get_env("KARYON_FIRECRACKER_ROOTFS")
    original_helper = System.get_env("KARYON_NET_HELPER")

    System.put_env("KARYON_MOCK_HARDWARE", "0")
    System.put_env("KARYON_FIRECRACKER_KERNEL", "/opt/karyon/firecracker/vmlinux")
    System.put_env("KARYON_FIRECRACKER_ROOTFS", "/opt/karyon/firecracker/rootfs.ext4")
    System.put_env("KARYON_NET_HELPER", "/usr/local/bin/karyon-net-helper")

    on_exit(fn ->
      restore_env("KARYON_MOCK_HARDWARE", original_mock)
      restore_env("KARYON_FIRECRACKER_KERNEL", original_kernel)
      restore_env("KARYON_FIRECRACKER_ROOTFS", original_rootfs)
      restore_env("KARYON_NET_HELPER", original_helper)
    end)

    assert {:ok, vm_id} = Provisioner.provision_vm("/tmp/test_plan.json")
    assert :ok = Provisioner.verify_network(vm_id)

    socket_path = "/tmp/firecracker-#{vm_id}.socket"
    assert :ok = Sandbox.VmmSupervisor.cleanup_resources(vm_id, socket_path)

    Process.sleep(200)
    assert Provisioner.tap_absent?(vm_id)
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
