defmodule Core.PreflightTest do
  use ExUnit.Case, async: true

  defmodule NativeOk do
    def read_numa_node, do: {:ok, 0}
    def get_affinity_mask, do: {:ok, [0, 1]}
  end

  defmodule NativeBadNuma do
    def read_numa_node, do: {:ok, 2}
    def get_affinity_mask, do: {:ok, [0, 1]}
  end

  test "run_checks/1 succeeds when topology evidence and affinity are valid" do
    assert :ok =
             Core.Preflight.run_checks(
               native_module: NativeOk,
               mock_hardware?: false,
               file_reader: fn
                 "/sys/devices/system/node/node0/meminfo" -> {:ok, "Node 0 MemTotal: 1234 kB"}
                 _ -> {:error, :enoent}
               end,
               dir_lister: fn _ -> {:error, :enoent} end,
               scheduler_bind_type_fun: fn :scheduler_bind_type -> :tnnps end,
               logical_processors_fun: fn :logical_processors -> 8 end
             )
  end

  test "run_checks/1 fails when memory topology evidence is missing" do
    assert {:error, reason} =
             Core.Preflight.run_checks(
               native_module: NativeOk,
               mock_hardware?: false,
               file_reader: fn _ -> {:error, :enoent} end,
               dir_lister: fn _ -> {:ok, []} end,
               scheduler_bind_type_fun: fn :scheduler_bind_type -> :tnnps end,
               logical_processors_fun: fn :logical_processors -> 8 end
             )

    assert reason =~ "memory topology evidence"
  end

  test "run_checks/1 fails when NUMA node is not local" do
    assert {:error, reason} =
             Core.Preflight.run_checks(
               native_module: NativeBadNuma,
               mock_hardware?: false,
               file_reader: fn
                 "/sys/devices/system/node/node0/meminfo" -> {:ok, "Node 0 MemTotal: 1234 kB"}
                 _ -> {:error, :enoent}
               end,
               dir_lister: fn _ -> {:ok, []} end,
               scheduler_bind_type_fun: fn :scheduler_bind_type -> :tnnps end,
               logical_processors_fun: fn :logical_processors -> 8 end
             )

    assert reason =~ "NUMA node"
  end
end
