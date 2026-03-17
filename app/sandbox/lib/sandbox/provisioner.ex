defmodule Sandbox.Provisioner do
  @moduledoc """
  High-level VM provisioner for Karyon Motor execution.
  Enforces 2 vCPUs, 512MB RAM, and air-gapped networking.
  """
  import Bitwise
  require Logger

  @doc """
  Provisions an isolated microVM for a specific execution plan.
  """
  def provision_vm(_plan_path) do
    vm_id = "vm-#{:erlang.unique_integer([:positive])}"
    socket_path = "/tmp/firecracker-#{vm_id}.socket"
    runtime = runtime_paths(vm_id)
    Sandbox.RuntimeRegistry.put(vm_id, runtime)
    
    # 1. Enforce SPEC.md constraints (2 vCPUs, 512MB RAM)
    vcpus = 2
    mem_size_mib = 512
    
    # 2. Setup air-gapped networking
    setup_network(vm_id)
    tap_device = "tap-#{vm_id}"

    # 3. Call Firecracker API to configure and start
    with {:ok, boot_requirements} <- firecracker_boot_requirements(),
         {:ok, vmm_pid} <- Sandbox.VmmSupervisor.start_vmm(vm_id, socket_path, boot_requirements, runtime),
         :ok <- wait_for_socket(socket_path),
         :ok <- setup_network(vm_id),
         :ok <- verify_network(vm_id), # Mandatory SPEC.md safety check
         :ok <- Sandbox.Firecracker.init_vmm(socket_path),
         :ok <- Sandbox.Firecracker.set_machine_config(socket_path, vcpus, mem_size_mib),
         :ok <- Sandbox.Firecracker.set_network_interface(socket_path, "eth0", tap_device),
         :ok <- Sandbox.Firecracker.set_boot_source(socket_path, boot_requirements.kernel_image_path, boot_args()),
         :ok <- Sandbox.Firecracker.set_drive(socket_path, "rootfs", boot_requirements.rootfs_path),
         :ok <- Sandbox.Firecracker.start_vm(socket_path) do
      # 4. Start log pipe
      Sandbox.RuntimeRegistry.update(vm_id, &Map.put(&1, :vmm_pid, vmm_pid))
      {:ok, _console_pid} = Sandbox.Console.start_link(vm_id: vm_id, pipe_path: runtime.stdout_path)
      
      Sandbox.RuntimeRegistry.update(vm_id, &Map.put(&1, :status, :running))
      Logger.info("[Sandbox.Provisioner] VM #{vm_id} successfully provisioned and started with telemetry capture.")
      {:ok, vm_id}
    else
      {:error, reason} -> 
        Logger.error("[Sandbox.Provisioner] Failed to provision VM: #{inspect(reason)}")
        Sandbox.RuntimeRegistry.update(vm_id, &Map.merge(&1, %{status: :failed, failure_reason: reason}))
        Sandbox.VmmSupervisor.cleanup_resources(vm_id, socket_path)
        {:error, reason}
      error ->
        Sandbox.RuntimeRegistry.update(vm_id, &Map.merge(&1, %{status: :failed, failure_reason: error}))
        {:error, error}
    end
  end

  @doc """
  Verifies the air-gap isolation of the VM via karyon-net-helper.
  """
  def verify_network(vm_id) do
    if System.get_env("KARYON_MOCK_HARDWARE") == "1" do
      :ok
    else
      tap_device = "tap-#{vm_id}"
      
      with {:ok, helper_path} <- helper_path() do
        case System.cmd(helper_path, ["verify", tap_device]) do
          {_, 0} -> :ok
          {output, _} -> 
            Logger.error("[Sandbox.Provisioner] AIR-GAP VERIFICATION FAILED for #{tap_device}: #{output}")
            {:error, :air_gap_validation_failed}
        end
      end
    end
  end

  defp wait_for_socket(path, attempts \\ 10) do
    if File.exists?(path) do
      :ok
    else
      if attempts > 0 do
        Process.sleep(100)
        wait_for_socket(path, attempts - 1)
      else
        {:error, :vmm_socket_not_ready}
      end
    end
  end

  @doc """
  Sets up the air-gapped networking for a VM.
  Exposed for testing and audit purposes.
  """
  def setup_network(vm_id) do
    tap_device = "tap-#{vm_id}"
    Logger.info("[Sandbox.Provisioner] Setting up hardened network for #{vm_id} via #{tap_device}")
    
    if System.get_env("KARYON_MOCK_HARDWARE") != "1" do
      # Use the secure karyon-net-helper binary
      bridge_name = Application.get_env(:sandbox, :bridge_device, "karyon0")

      with {:ok, helper_path} <- helper_path() do
        case System.cmd(helper_path, ["setup", tap_device, bridge_name]) do
          {_, 0} -> :ok
          {error, _} -> 
            Logger.error("[Sandbox.Provisioner] FAILED to setup network via helper: #{error}")
            {:error, :network_setup_failed}
        end
      end
    else
      Logger.info("[Sandbox.Provisioner] MOCK: Skipping real network setup for #{tap_device}")
      :ok
    end
  end

  # Legacy sudo setup removed for security hardening.
  # Production systems must use karyon-net-helper with restricted privileges.

  @doc """
  Verifies that a workspace path is safe to mount via virtio-fs.
  Ensures it is trapped within the ~/.karyon/sandboxes/ directory.
  """
  def verify_mount_safety(path) do
    abs_path = Path.expand(path)
    base_sandbox_dir = Path.expand("~/.karyon/sandboxes")

    case Path.relative_to(abs_path, base_sandbox_dir) do
      relative when relative in [".", ""] ->
        {:ok, abs_path}

      relative when is_binary(relative) ->
        if String.starts_with?(relative, "..") or Path.type(relative) == :absolute do
          Logger.error("[Sandbox.Provisioner] SECURITY VIOLATION: Attempted to mount path outside of sandbox jail: #{abs_path}")
          {:error, :unsafe_mount_path}
        else
          {:ok, abs_path}
        end

      _ ->
        Logger.error("[Sandbox.Provisioner] SECURITY VIOLATION: Attempted to mount path outside of sandbox jail: #{abs_path}")
        {:error, :unsafe_mount_path}
    end
  end

  @doc """
  Verifies that the VM tap device has been removed after cleanup.
  Exposed for isolation validation.
  """
  def tap_absent?(vm_id) do
    not File.exists?("/sys/class/net/tap-#{vm_id}")
  end

  @doc """
  Verifies that a specific mount path remains trapped within the sandbox jail.
  Intended for end-to-end audit flows.
  """
  def verify_mount_isolation(path) do
    case verify_mount_safety(path) do
      {:ok, safe_path} ->
        if File.exists?(safe_path) and match?({:ok, %File.Stat{type: :symlink}}, File.lstat(safe_path)) do
          Logger.error("[Sandbox.Provisioner] SECURITY VIOLATION: Symlink mounts are not allowed inside sandbox jail: #{safe_path}")
          {:error, :unsafe_mount_path}
        else
          {:ok, safe_path}
        end

      error ->
        error
    end
  end

  @doc """
  Captures execution output and pipes back to Karyon engine.
  """
  def capture_output(vm_id) do
    Logger.info("[Sandbox.Provisioner] Capturing output from #{vm_id}")

    if System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"] do
      {:ok, %{stdout: "mock execution", stderr: "", exit_code: 0, vm_id: vm_id, mode: :mock}}
    else
      case Sandbox.RuntimeRegistry.get(vm_id) do
        nil ->
          {:error, :vm_runtime_not_found}

        runtime ->
          result = %{
            stdout: read_output(runtime.stdout_path),
            stderr: read_output(runtime.stderr_path),
            exit_code: runtime[:exit_code],
            vm_id: vm_id,
            mode: :firecracker,
            status: runtime[:status] || :unknown
          }

          maybe_signal_capture_failure(vm_id, runtime, result)
          {:ok, result}
      end
    end
  end

  @doc """
  Resolves the `karyon-net-helper` executable path from configuration, environment,
  PATH discovery, or known sandbox build output directories.
  """
  def helper_path do
    case Enum.find(helper_candidates(), &valid_helper_path?/1) do
      nil ->
        {:error, :net_helper_not_found}

      path ->
        {:ok, path}
    end
  end

  defp firecracker_boot_requirements do
    if System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"] do
      {:ok, %{binary_path: "mock-firecracker", kernel_image_path: "mock-kernel", rootfs_path: "mock-rootfs"}}
    else
      Sandbox.Firecracker.boot_requirements()
    end
  end

  defp boot_args do
    Application.get_env(
      :sandbox,
      :firecracker_boot_args,
      "console=ttyS0 reboot=k panic=1 pci=off"
    )
  end

  defp helper_candidates do
    [
      Application.get_env(:sandbox, :net_helper_path),
      System.get_env("KARYON_NET_HELPER"),
      System.find_executable("karyon-net-helper"),
      System.find_executable("net_helper"),
      Path.join([sandbox_root(), "native", "net_helper", "target", "release", "karyon-net-helper"]),
      Path.join([sandbox_root(), "native", "net_helper", "target", "release", "net_helper"]),
      Path.join([sandbox_root(), "native", "net_helper", "target", "debug", "karyon-net-helper"]),
      Path.join([sandbox_root(), "native", "net_helper", "target", "debug", "net_helper"]),
      Path.expand("../../native/net_helper/target/release/karyon-net-helper", __DIR__),
      Path.expand("../../native/net_helper/target/release/net_helper", __DIR__),
      Path.expand("../../native/net_helper/target/debug/karyon-net-helper", __DIR__),
      Path.expand("../../native/net_helper/target/debug/net_helper", __DIR__)
    ]
  end

  defp valid_helper_path?(path) when is_binary(path) do
    File.regular?(path) and executable?(path)
  end

  defp valid_helper_path?(_path), do: false

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} -> (mode &&& 0o111) != 0
      _ -> false
    end
  end

  defp sandbox_root do
    case Application.app_dir(:sandbox) do
      path when is_binary(path) -> path
      _ -> Path.expand("../..", __DIR__)
    end
  end

  defp runtime_paths(vm_id) do
    %{
      stdout_path: "/tmp/firecracker-#{vm_id}.stdout.log",
      stderr_path: "/tmp/firecracker-#{vm_id}.stderr.log",
      status: :starting,
      exit_code: nil,
      pain_reported: false
    }
  end

  defp read_output(path) when is_binary(path) do
    case File.read(path) do
      {:ok, contents} -> contents
      {:error, :enoent} -> ""
      {:error, _reason} -> ""
    end
  end

  defp maybe_signal_capture_failure(vm_id, runtime, result) do
    failure? =
      runtime[:exit_code] not in [nil, 0] or
        String.contains?(result.stdout <> result.stderr, ["ERROR", "PANIC", "Exception", "Kernel panic"])

    if failure? and not runtime[:pain_reported] do
      NervousSystem.PainReceptor.trigger_nociception(%{
        origin: "sandbox_capture",
        vm_id: vm_id,
        severity: :high,
        exit_code: result.exit_code,
        stderr: String.trim(result.stderr)
      })

      Sandbox.RuntimeRegistry.update(vm_id, &Map.put(&1, :pain_reported, true))
    end
  end
end
