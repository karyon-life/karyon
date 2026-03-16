defmodule Core.NativeTest do
  use ExUnit.Case
  alias Core.Native

  test "read_numa_node returns a valid node index" do
    assert {:ok, node} = Native.read_numa_node()
    assert is_integer(node)
    assert node >= -1
  end

  test "read_cpu_index returns a valid cpu index" do
    assert {:ok, cpu} = Native.read_cpu_index()
    assert is_integer(cpu)
    assert cpu >= 0
  end

  test "read_l3_misses returns a value" do
    Native.set_native_mock(nil, 1337, false)
    assert {:ok, misses} = Native.read_l3_misses()
    assert misses == 1337
  end

  test "read_l3_misses handles failure" do
    Native.set_native_mock(nil, nil, true)
    assert {:error, 0} = Native.read_l3_misses()
  end

  test "read_iops returns a value" do
    Native.set_native_mock(42, nil, false)
    assert {:ok, iops} = Native.read_iops()
    assert iops == 42
  end

  test "read_iops handles failure" do
    Native.set_native_mock(nil, nil, true)
    assert {:error, 0} = Native.read_iops()
  end
end
