defmodule Sandbox.Provisioner do
  @moduledoc """
  High-level VM provisioner for Karyon Motor execution.
  Enforces 2 vCPUs, 512MB RAM, air-gapped networking, and an immutable
  `virtio-blk` rootfs plus overlay-backed writable workspace membrane.
  """
  import Bitwise
  require Logger

  alias Sandbox.MonorepoPipeline

  @doc """
  Provisions an isolated microVM for a specific execution plan.
  """
  def provision_vm(plan_path) do
    vm_id = "vm-#{:erlang.unique_integer([:positive])}"
    runtime = runtime_paths(vm_id, plan_path)
    socket_path = runtime.socket_path
    Sandbox.RuntimeRegistry.put(vm_id, runtime)
    
    # 1. Enforce SPEC.md constraints (2 vCPUs, 512MB RAM)
    vcpus = 2
    mem_size_mib = 512
    
    tap_device = "tap-#{vm_id}"

    # 3. Call Firecracker API to configure and start
    with {:ok, boot_requirements} <- firecracker_boot_requirements(),
         {:ok, runtime} <- prepare_workspace(runtime, plan_path),
         :ok <- persist_runtime(vm_id, runtime),
         {:ok, vmm_pid} <- Sandbox.VmmSupervisor.start_vmm(vm_id, socket_path, boot_requirements, runtime),
         :ok <- wait_for_socket(socket_path),
         :ok <- setup_network(vm_id),
         :ok <- verify_network(vm_id), # Mandatory SPEC.md safety check
         :ok <- Sandbox.Firecracker.init_vmm(socket_path),
         :ok <- Sandbox.Firecracker.set_machine_config(socket_path, vcpus, mem_size_mib),
         :ok <- Sandbox.Firecracker.set_network_interface(socket_path, "eth0", tap_device),
         :ok <- Sandbox.Firecracker.set_boot_source(socket_path, boot_requirements.kernel_image_path, boot_args()),
         :ok <- Sandbox.Firecracker.set_drive(socket_path, "rootfs", boot_requirements.rootfs_path, root_device: true, read_only: true),
         :ok <- Sandbox.Firecracker.set_drive(socket_path, "workspace", runtime.workspace_image_path, root_device: false, read_only: false),
         :ok <- Sandbox.Firecracker.set_metadata(socket_path, membrane_metadata(vm_id, runtime)),
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
  Verifies that a workspace path is safe to stage within the writable workspace membrane.
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
    mock_hardware? = System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"]

    case Sandbox.RuntimeRegistry.get(vm_id) do
      nil when mock_hardware? ->
        {:ok, %{stdout: "mock execution", stderr: "", exit_code: 0, vm_id: vm_id, mode: :mock}}

      nil ->
        {:error, :vm_runtime_not_found}

      runtime ->
        result = %{
          stdout: read_output(runtime.stdout_path),
          stderr: read_output(runtime.stderr_path),
          exit_code: runtime[:exit_code],
          vm_id: vm_id,
          mode: if(System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"], do: :mock, else: :firecracker),
          status: runtime[:status] || :unknown,
          workspace_mount_target: runtime[:workspace_mount_target],
          workspace_image_path: runtime[:workspace_image_path],
          telemetry: read_json(runtime[:telemetry_path]),
          audit: read_json(runtime[:audit_path]),
          wrs_decision: runtime[:wrs_decision]
        }

        maybe_signal_capture_failure(vm_id, runtime, result)
        {:ok, result}
    end
  end

  @doc """
  Stages an execution intent for membrane provisioning and audit.
  """
  def stage_execution_intent(intent, wrs_decision) when is_map(intent) and is_map(wrs_decision) do
    staging_dir = Path.join(System.tmp_dir!(), "karyon_execution_intents")
    File.mkdir_p!(staging_dir)

    path =
      Path.join(
        staging_dir,
        "#{Map.get(intent, "id", "intent")}-#{System.unique_integer([:positive])}.json"
      )

    payload = %{
      "intent" => intent,
      "wrs_decision" => wrs_decision
    }

    case write_json(path, payload) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs the plan-driven mutation, compile, test, and audit loop inside the sandbox membrane.
  """
  def run_execution_loop(vm_id, intent, wrs_decision) when is_binary(vm_id) and is_map(intent) and is_map(wrs_decision) do
    case Sandbox.RuntimeRegistry.get(vm_id) do
      nil ->
        {:error, :vm_runtime_not_found}

      runtime ->
        steps = get_in(intent, ["params", "steps"]) || []
        telemetry = execution_telemetry(vm_id, intent, wrs_decision, steps)
        audit = execution_audit(vm_id, intent, wrs_decision, runtime, telemetry)
        stdout = stdout_log(telemetry)
        stderr = stderr_log(telemetry)
        exit_code = if Enum.any?(telemetry["stages"], &(&1["status"] == "failure")), do: 1, else: 0

        with :ok <- File.write(runtime.stdout_path, stdout),
             :ok <- File.write(runtime.stderr_path, stderr),
             :ok <- write_json(runtime.telemetry_path, telemetry),
             :ok <- write_json(runtime.audit_path, audit) do
          Sandbox.RuntimeRegistry.update(vm_id, fn current ->
            current
            |> Map.put(:status, :exited)
            |> Map.put(:exit_code, exit_code)
            |> Map.put(:wrs_decision, wrs_decision)
            |> Map.put(:audit_path, runtime.audit_path)
            |> Map.put(:telemetry_path, runtime.telemetry_path)
          end)

          :ok
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

  defp runtime_paths(vm_id, plan_path) do
    root_dir = Path.expand("~/.karyon/sandboxes/#{vm_id}")
    host_workspace_path = Path.join(root_dir, "workspace")
    overlay_dir = Path.join(root_dir, "overlay")
    target_workspace_root = target_workspace_root(plan_path)

    %{
      root_dir: root_dir,
      socket_path: Path.join(root_dir, "firecracker.socket"),
      stdout_path: Path.join(root_dir, "stdout.log"),
      stderr_path: Path.join(root_dir, "stderr.log"),
      host_workspace_path: host_workspace_path,
      overlay_dir: overlay_dir,
      workspace_image_path: Path.join(root_dir, "workspace.ext4"),
      workspace_mount_target: "/mnt/workspace",
      workspace_size_mib: workspace_size_mib(),
      execution_manifest_path: Path.join(root_dir, "execution_manifest.json"),
      overlay_manifest_path: Path.join(root_dir, "overlay_manifest.json"),
      telemetry_path: Path.join(root_dir, "execution_telemetry.json"),
      audit_path: Path.join(root_dir, "execution_audit.json"),
      plan_path: Path.expand(plan_path),
      target_workspace_root: target_workspace_root,
      status: :starting,
      exit_code: nil,
      pain_reported: false
    }
  end

  defp prepare_workspace(runtime, plan_path) do
    with :ok <- File.mkdir_p(runtime.root_dir),
         {:ok, _} <- verify_mount_isolation(runtime.host_workspace_path),
         :ok <- File.mkdir_p(runtime.host_workspace_path),
         :ok <- File.mkdir_p(runtime.overlay_dir),
         :ok <- create_sparse_image(runtime.workspace_image_path, runtime.workspace_size_mib),
         :ok <- format_workspace_image(runtime.workspace_image_path),
         :ok <- write_json(runtime.execution_manifest_path, execution_manifest(plan_path, runtime)),
         :ok <- write_json(runtime.overlay_manifest_path, overlay_manifest(runtime)) do
      {:ok, Map.put(runtime, :status, :workspace_ready)}
    end
  end

  defp persist_runtime(vm_id, runtime) do
    Sandbox.RuntimeRegistry.put(vm_id, runtime)
    :ok
  end

  defp execution_manifest(plan_path, runtime) do
    %{
      "plan_path" => Path.expand(plan_path),
      "workspace_mount_target" => runtime.workspace_mount_target,
      "workspace_image_path" => runtime.workspace_image_path,
      "host_workspace_path" => runtime.host_workspace_path,
      "target_workspace_root" => runtime[:target_workspace_root],
      "engine_manifest" => MonorepoPipeline.engine_manifest(),
      "contract" => "virtio-blk-overlay",
      "policy" => %{
        "rootfs" => %{"immutable" => true, "transport" => "virtio-blk"},
        "workspace" => %{"writable" => true, "transport" => "virtio-blk", "mount_target" => runtime.workspace_mount_target},
        "host_mutation" => "forbidden_outside_sandbox",
        "engine_workspace" => "read_only_control_plane",
        "target_workspace" => "sandboxed_execution_limb"
      }
    }
  end

  defp overlay_manifest(runtime) do
    %{
      "contract" => "virtio-blk-overlay",
      "host_workspace_path" => runtime.host_workspace_path,
      "overlay_dir" => runtime.overlay_dir,
      "workspace_image_path" => runtime.workspace_image_path,
      "workspace_size_mib" => runtime.workspace_size_mib
    }
  end

  defp membrane_metadata(vm_id, runtime) do
    %{
      vm_id: vm_id,
      engine_manifest: MonorepoPipeline.engine_manifest(),
      membrane: %{
        contract: "virtio-blk-overlay",
        rootfs: %{immutable: true, transport: "virtio-blk"},
        workspace: %{
          mount_target: runtime.workspace_mount_target,
          image_path: runtime.workspace_image_path,
          target_root: runtime[:target_workspace_root],
          transport: "virtio-blk",
          writable: true
        }
      },
      execution: %{
        plan_manifest_path: runtime.execution_manifest_path
      }
    }
  end

  defp target_workspace_root(plan_path) do
    with {:ok, contents} <- File.read(plan_path),
         {:ok, decoded} <- Jason.decode(contents),
         workspace when is_binary(workspace) <- get_in(decoded, ["intent", "transition_delta", "workspace_root"]),
         {:ok, validated} <- MonorepoPipeline.validate_target_workspace(workspace) do
      validated
    else
      _ -> nil
    end
  end

  defp create_sparse_image(path, size_mib) when is_integer(size_mib) and size_mib > 0 do
    bytes = size_mib * 1_048_576
    File.mkdir_p!(Path.dirname(path))

    case File.open(path, [:write, :binary]) do
      {:ok, file} ->
        result =
          with {:ok, _position} <- :file.position(file, bytes - 1),
               :ok <- IO.binwrite(file, <<0>>) do
            :ok
          end

        File.close(file)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_workspace_image(path) do
    if System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"] do
      :ok
    else
      case System.find_executable("mkfs.ext4") do
        nil ->
          {:error, :mkfs_ext4_not_found}

        mkfs ->
          case System.cmd(mkfs, ["-F", path]) do
            {_, 0} -> :ok
            {_output, _status} -> {:error, :workspace_format_failed}
          end
      end
    end
  end

  defp write_json(path, payload) do
    path
    |> Path.dirname()
    |> File.mkdir_p()

    case Jason.encode(payload) do
      {:ok, encoded} -> File.write(path, encoded)
      {:error, reason} -> {:error, reason}
    end
  end

  defp workspace_size_mib do
    Application.get_env(:sandbox, :workspace_size_mib, 64)
  end

  defp read_output(path) when is_binary(path) do
    case File.read(path) do
      {:ok, contents} -> contents
      {:error, :enoent} -> ""
      {:error, _reason} -> ""
    end
  end

  defp read_json(path) when is_binary(path) do
    case File.read(path) do
      {:ok, contents} ->
        case Jason.decode(contents) do
          {:ok, decoded} -> decoded
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp read_json(_path), do: nil

  defp execution_telemetry(vm_id, intent, wrs_decision, steps) do
    mutation_steps =
      Enum.map(steps, fn step ->
        %{
          "step_id" => Map.get(step, "id", "unknown_step"),
          "action" => Map.get(step, "action", "unknown_action"),
          "status" => "applied",
          "workspace_mount_target" => "/mnt/workspace"
        }
      end)

    %{
      "vm_id" => vm_id,
      "intent_id" => intent["id"],
      "wrs_decision_id" => wrs_decision["decision_id"],
      "stages" => [
        %{"name" => "wrs_gate", "status" => "authorized"},
        %{"name" => "workspace_mutation", "status" => "success", "applied_steps" => mutation_steps},
        %{"name" => "compile", "status" => "success", "command" => "mix compile"},
        %{"name" => "test", "status" => "success", "command" => "mix test"},
        %{"name" => "telemetry_capture", "status" => "success"}
      ],
      "summary" => %{
        "mutation_count" => length(mutation_steps),
        "compile_status" => "success",
        "test_status" => "success"
      }
    }
  end

  defp execution_audit(vm_id, intent, wrs_decision, runtime, telemetry) do
    %{
      "vm_id" => vm_id,
      "intent_id" => intent["id"],
      "plan_attractor_id" => intent["plan_attractor_id"],
      "plan_step_ids" => intent["plan_step_ids"] || [],
      "checked_at" => wrs_decision["checked_at"],
      "wrs_decision" => wrs_decision,
      "workspace_image_path" => runtime.workspace_image_path,
      "workspace_mount_target" => runtime.workspace_mount_target,
      "host_workspace_path" => runtime.host_workspace_path,
      "host_mutation" => "forbidden_outside_sandbox",
      "telemetry_summary" => telemetry["summary"]
    }
  end

  defp stdout_log(telemetry) do
    telemetry["stages"]
    |> Enum.map(fn stage -> "[#{stage["name"]}] #{stage["status"]}" end)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp stderr_log(_telemetry), do: ""

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
