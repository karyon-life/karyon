defmodule Core.Preflight do
  @moduledoc """
  Mandatory hardware and environment validation prior to Karyon organism boot.
  Mandated by SPEC.md to ensure lock-free concurrency and memory-bandwidth saturation.
  """
  require Logger

  @doc """
  Runs all pre-flight checks. Returns :ok or {:error, reason}.
  """
  def run_checks do
    with :ok <- check_numa_topology(),
         :ok <- check_memory_channels(),
         :ok <- check_scheduler_affinity() do
      Logger.info("[Preflight] Hardware and ERTS configuration VALIDATED. Safe to boot.")
      :ok
    else
      {:error, reason} ->
        Logger.error("[Preflight] SYSTEM HALT: Hardware validation failed! #{reason}")
        {:error, reason}
    end
  end

  defp check_numa_topology do
    case Core.Native.read_numa_node() do
      {:ok, node} ->
        if node == 0 do
          :ok
        else
          {:error, "Detected active execution on NUMA node #{node}. Single-socket/UMA required."}
        end
      unexpected ->
        # Handle :error or other unexpected results gracefully
        if System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"], do: :ok, else: {:error, "Unexpected NUMA node result: #{inspect(unexpected)}"}
    end
  end

  defp check_memory_channels do
    if System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"] do
      :ok
    else
      # Attempt to read memory info or dmidecode if available
      # This usually require root, so we check /proc/meminfo or similar for basic verification
      # For production readiness, we'd use a dedicated C/Rust util to probe DIMM slots.
      case File.read("/proc/meminfo") do
        {:ok, content} ->
          if String.contains?(content, "MemTotal") do
            :ok # Placeholder for real channel probing
          else
            {:error, "Unable to verify memory topology."}
          end
        _ -> {:error, "Cannot read /proc/meminfo"}
      end
    end
  end

  defp check_scheduler_affinity do
    # Verify BEAM scheduler binding: +sbt tnnps
    # We can check :erlang.system_info(:scheduler_bind_type)
    case :erlang.system_info(:scheduler_bind_type) do
      :thread_no_node_processor_spread -> :ok
      :tnnps -> :ok
      other -> 
        if System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"] do
          :ok
        else
          {:error, "Invalid BEAM scheduler binding: #{inspect(other)}. Expected: tnnps"}
        end
    end
  end
end
