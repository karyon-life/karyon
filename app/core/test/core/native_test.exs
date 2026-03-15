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
    # This might fail on some CI environments if perf_event is restricted, 
    # but we have a mock mode in the NIF if KARYON_MOCK_HARDWARE is set.
    System.put_env("KARYON_MOCK_HARDWARE", "true")
    assert {:ok, misses} = Native.read_l3_misses()
    assert misses == 100
  end
end
