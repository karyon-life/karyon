defmodule Rhizome.MemoryTopologyContract do
  import ExUnit.Assertions

  def assert_operation(operation, expected_layer, expected_store) do
    descriptor = Rhizome.Memory.topology_for(operation)

    assert descriptor.layer == expected_layer
    assert descriptor.store == expected_store
    assert descriptor.access in [:read, :write, :read_write]
    assert is_binary(descriptor.purpose)
    assert descriptor.purpose != ""

    descriptor
  end

  def assert_contract_layer(layer, expected_store, expected_operations) do
    descriptor = Rhizome.MemoryTopology.descriptor(layer)

    assert descriptor.layer == layer
    assert descriptor.store == expected_store
    assert Enum.sort(descriptor.operations) == Enum.sort(expected_operations)

    descriptor
  end
end
