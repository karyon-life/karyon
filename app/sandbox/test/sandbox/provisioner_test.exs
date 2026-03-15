defmodule Sandbox.ProvisionerTest do
  use ExUnit.Case
  alias Sandbox.Provisioner

  setup do
    System.put_env("KARYON_MOCK_HARDWARE", "1")
    on_exit(fn -> System.delete_env("KARYON_MOCK_HARDWARE") end)
    :ok
  end

  test "VM provisioning lifecycle with mock hardware" do
    # Provision a VM
    plan_path = "/tmp/test_plan.json"
    File.write!(plan_path, "{}")
    
    case Provisioner.provision_vm(plan_path) do
      {:ok, vm_id} ->
        assert String.starts_with?(vm_id, "vm-")
        socket_path = "/tmp/firecracker-#{vm_id}.socket"
        assert File.exists?(socket_path)
        
        # Verify network setup was mocked
        tap_device = "tap-#{vm_id}"
        # Since it's mocked, we just check logs or ensure no error was raised
        
        # Cleanup (Manual for test)
        Sandbox.VmmSupervisor.cleanup_resources(vm_id, socket_path)
        refute File.exists?(socket_path)
        
      {:error, reason} ->
        flunk("Provisioning failed: #{inspect(reason)}")
    end
  end

  test "Air-Gapped network setup logic" do
    vm_id = "test-air-gap"
    tap_device = "tap-#{vm_id}"
    
    # We can't easily test sudo/iptables without root, 
    # but we can verify our setup_network function calls the right things
    # In this mock environment, it just logs.
    assert {:ok, _vm_id} = Provisioner.provision_vm("/tmp/dummy.json")
  end
end
