defmodule Sandbox.VmmSupervisor do
  @moduledoc """
  Manages the dynamic lifecycle of Firecracker MicroVM processes and their
  associated sidecars (log pipes, etc.).

  The BEAM application does not perform privileged host cleanup directly.
  Any tap-device cleanup must be delegated to the restricted `karyon-net-helper`
  host boundary.
  """
  use DynamicSupervisor

  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Spawns a new VMM child under supervision.
  """
  def start_vmm(id, socket_path, boot_requirements \\ nil, runtime \\ nil) do
    child_spec = %{
      id: {:vmm, id},
      start: {Task, :start_link, [fn -> spawn_firecracker(id, socket_path, boot_requirements, runtime) end]},
      restart: :temporary
    }
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  defp spawn_firecracker(id, socket_path, boot_requirements, runtime) do
    # Ensure cleanup before starting
    _ = cleanup_resources(id, socket_path)
    runtime = prepare_runtime(id, runtime)
    
    # In a real environment, this would call the firecracker binary.
    # We use a Task to represent the long-running process.
    if System.get_env("KARYON_MOCK_HARDWARE") == "1" do
      Sandbox.RuntimeRegistry.update(id, &Map.merge(&1, %{status: :running, exit_code: 0}))

      # Mock: create the socket so Sandbox.Firecracker doesn't error
      # In reality, Firecracker creates this immediately on start
      File.touch!(socket_path)
      Process.sleep(:infinity)
    else
      initialize_runtime_files(runtime)
      Sandbox.RuntimeRegistry.update(id, &Map.merge(&1, %{status: :running, exit_code: nil}))

      run_firecracker(id, socket_path, boot_requirements, runtime)
    end
  end

  @doc """
  Cleans up VMM resources.
  """
  def cleanup_resources(id, socket_path) do
    stop_vmm(id)
    terminate_firecracker(socket_path)
    File.rm(socket_path)

    if System.get_env("KARYON_MOCK_HARDWARE") != "1" do
      cleanup_tap_device("tap-#{id}")
    else
      :ok
    end
  end

  defp cleanup_tap_device(tap_device) do
    with {:ok, helper_path} <- Sandbox.Provisioner.helper_path() do
      case System.cmd(helper_path, ["cleanup", tap_device]) do
        {_, 0} ->
          :ok

        {output, _status} ->
          Logger.error("[Sandbox.VmmSupervisor] Helper cleanup failed for #{tap_device}: #{output}")
          {:error, :network_cleanup_failed}
      end
    else
      {:error, :net_helper_not_found} = error ->
        Logger.error("[Sandbox.VmmSupervisor] Network cleanup helper unavailable for #{tap_device}")
        error
    end
  end

  defp prepare_runtime(id, runtime) do
    runtime = runtime || default_runtime(id)
    Sandbox.RuntimeRegistry.put(id, runtime)
    runtime
  end

  defp default_runtime(id) do
    %{
      stdout_path: "/tmp/firecracker-#{id}.stdout.log",
      stderr_path: "/tmp/firecracker-#{id}.stderr.log",
      status: :starting,
      exit_code: nil,
      pain_reported: false
    }
  end

  defp initialize_runtime_files(runtime) do
    File.mkdir_p!(Path.dirname(runtime.stdout_path))
    File.write!(runtime.stdout_path, "")
    File.write!(runtime.stderr_path, "")
  end

  defp run_firecracker(id, socket_path, boot_requirements, runtime) do
    port =
      Port.open(
        {:spawn_executable, "/bin/sh"},
        [
          :binary,
          :exit_status,
          :hide,
          args: [
            "-c",
            ~s(exec "$0" --api-sock "$1" >"$2" 2>"$3"),
            boot_requirements.binary_path,
            socket_path,
            runtime.stdout_path,
            runtime.stderr_path
          ]
        ]
      )

    Sandbox.RuntimeRegistry.update(id, &Map.put(&1, :vmm_port, port))

    exit_code =
      receive do
        {^port, {:exit_status, status}} -> status
      end

    Sandbox.RuntimeRegistry.update(id, &Map.merge(&1, %{status: :exited, exit_code: exit_code}))

    if exit_code != 0 do
      stderr = read_runtime_file(runtime.stderr_path)

      NervousSystem.PainReceptor.trigger_nociception(%{
        origin: "firecracker",
        vm_id: id,
        severity: :high,
        exit_code: exit_code,
        stderr: stderr
      })

      Sandbox.RuntimeRegistry.update(id, &Map.put(&1, :pain_reported, true))
      Logger.error("[Sandbox.VmmSupervisor] Firecracker exited for #{id} with code #{exit_code}")
    end
  end

  defp read_runtime_file(path) do
    case File.read(path) do
      {:ok, contents} -> String.trim(contents)
      _ -> ""
    end
  end

  defp stop_vmm(id) do
    case Sandbox.RuntimeRegistry.get(id) do
      %{vmm_pid: pid} = runtime when is_pid(pid) ->
        stop_vmm_port(runtime)

        if Process.alive?(pid) do
          monitor = Process.monitor(pid)
          Process.exit(pid, :kill)

          receive do
            {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
          after
            1_000 -> :ok
          end
        end

        Sandbox.RuntimeRegistry.update(id, &Map.put(&1, :status, :stopped))
        :ok

      _ ->
        :ok
    end
  end

  defp stop_vmm_port(%{vmm_port: port}) when is_port(port) do
    if Port.info(port) != nil do
      Port.close(port)
      Process.sleep(100)
    end

    :ok
  end

  defp stop_vmm_port(_runtime), do: :ok

  defp terminate_firecracker(socket_path) do
    case System.find_executable("pkill") do
      nil ->
        :ok

      pkill ->
        _ = System.cmd(pkill, ["-f", "firecracker --api-sock #{socket_path}"])
        Process.sleep(100)
        :ok
    end
  end
end
