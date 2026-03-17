defmodule Core.Preflight do
  @moduledoc """
  Mandatory hardware and environment validation prior to Karyon organism boot.
  Mandated by SPEC.md to ensure lock-free concurrency and memory-bandwidth saturation.
  """
  require Logger

  @doc """
  Runs all pre-flight checks. Returns :ok or {:error, reason}.
  """
  def run_checks(opts \\ []) do
    with :ok <- check_numa_topology(opts),
         :ok <- check_memory_topology(opts),
         :ok <- check_scheduler_affinity(opts) do
      Logger.info("[Preflight] Hardware and ERTS configuration VALIDATED. Safe to boot.")
      :ok
    else
      {:error, reason} ->
        Logger.error("[Preflight] SYSTEM HALT: Hardware validation failed! #{reason}")
        {:error, reason}
    end
  end

  defp check_numa_topology(opts) do
    case native_module(opts).read_numa_node() do
      {:ok, node} ->
        if node == 0 do
          :ok
        else
          {:error, "Detected active execution on NUMA node #{node}. Single-socket/UMA required."}
        end
      unexpected ->
        # Handle :error or other unexpected results gracefully
        if mock_hardware?(opts), do: :ok, else: {:error, "Unexpected NUMA node result: #{inspect(unexpected)}"}
    end
  end

  defp check_memory_topology(opts) do
    if mock_hardware?(opts) do
      :ok
    else
      edac_dir = Keyword.get(opts, :edac_dir, "/sys/devices/system/edac/mc")
      node_meminfo = Keyword.get(opts, :node_meminfo_path, "/sys/devices/system/node/node0/meminfo")
      file_reader = Keyword.get(opts, :file_reader, &File.read/1)
      dir_lister = Keyword.get(opts, :dir_lister, &File.ls/1)

      cond do
        edac_channels_present?(edac_dir, dir_lister) ->
          :ok

        node_meminfo_present?(node_meminfo, file_reader) ->
          :ok

        true ->
          {:error, "Unable to verify memory topology evidence from EDAC or node meminfo."}
      end
    end
  end

  defp check_scheduler_affinity(opts) do
    # Verify BEAM scheduler binding: +sbt tnnps
    scheduler_bind_type = Keyword.get(opts, :scheduler_bind_type_fun, &:erlang.system_info/1)

    case scheduler_bind_type.(:scheduler_bind_type) do
      :thread_no_node_processor_spread -> 
        validate_affinity_mask(opts)
      :tnnps -> 
        validate_affinity_mask(opts)
      other -> 
        if mock_hardware?(opts) do
          :ok
        else
          {:error, "Invalid BEAM scheduler binding: #{inspect(other)}. Expected: tnnps"}
        end
    end
  end

  defp validate_affinity_mask(opts) do
    logical_processors_fun = Keyword.get(opts, :logical_processors_fun, &:erlang.system_info/1)

    case native_module(opts).get_affinity_mask() do
      {:ok, bits} ->
        # For a production organism, we expect specific pinning.
        # Minimal check: ensure we are pinned to SPECIFIC CPUs (not all of them)
        if length(bits) > 0 and length(bits) < logical_processors_fun.(:logical_processors) do
          Logger.info("[Preflight] Affinity mask validated: #{inspect(bits)}")
          :ok
        else
          if mock_hardware?(opts) do
             :ok
          else
             {:error, "Thread affinity too broad. Migration risks detected. Mask: #{inspect(bits)}"}
          end
        end
      {:error, _} ->
        if mock_hardware?(opts) do
          :ok
        else
          {:error, "Failed to retrieve CPU affinity mask."}
        end
    end
  end

  defp edac_channels_present?(path, dir_lister) do
    case dir_lister.(path) do
      {:ok, entries} -> Enum.any?(entries, &String.starts_with?(&1, "mc"))
      _ -> false
    end
  end

  defp node_meminfo_present?(path, file_reader) do
    case file_reader.(path) do
      {:ok, content} ->
        String.contains?(content, "MemTotal") and String.contains?(content, "Node 0")

      _ ->
        false
    end
  end

  defp native_module(opts), do: Keyword.get(opts, :native_module, Core.Native)

  defp mock_hardware?(opts) do
    Keyword.get_lazy(opts, :mock_hardware?, fn ->
      System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"]
    end)
  end
end
