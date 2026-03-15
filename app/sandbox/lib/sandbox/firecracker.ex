defmodule Sandbox.Firecracker do
  @moduledoc """
  Low-level API wrapper for the AWS Firecracker microVM engine.
  Handles socket communication and VMM configuration using HTTP over UDS.
  """
  require Logger

  @doc """
  Initializes a Firecracker VMM via the control socket.
  """
  def init_vmm(socket_path) do
    Logger.info("[Sandbox.Firecracker] Initializing VMM at #{socket_path}")
    put_request(socket_path, "/version", %{})
  end

  @doc """
  Configures the boot source (kernel and boot args).
  """
  def set_boot_source(socket_path, kernel_path, boot_args) do
    Logger.info("[Sandbox.Firecracker] Setting boot source: #{kernel_path}")
    body = %{
      kernel_image_path: kernel_path,
      boot_args: boot_args
    }
    put_request(socket_path, "/boot-source", body)
  end

  @doc """
  Configures a drive (rootfs).
  """
  def set_drive(socket_path, drive_id, path) do
    Logger.info("[Sandbox.Firecracker] Setting drive #{drive_id}: #{path}")
    body = %{
      drive_id: drive_id,
      path_on_host: Path.expand(path),
      is_root_device: drive_id == "rootfs",
      is_read_only: false
    }
    put_request(socket_path, "/drives/#{drive_id}", body)
  end

  @doc """
  Configures a network interface.
  """
  def set_network_interface(socket_path, iface_id, host_dev_name) do
    Logger.info("[Sandbox.Firecracker] Setting network interface #{iface_id}: #{host_dev_name}")
    body = %{
      iface_id: iface_id,
      host_dev_name: host_dev_name,
      allow_mmds_requests: false
    }
    put_request(socket_path, "/network-interfaces/#{iface_id}", body)
  end

  @doc """
  Sets the machine configuration (vCPU count and memory size).
  """
  def set_machine_config(socket_path, vcpu_count, mem_size_mib) do
    Logger.info("[Sandbox.Firecracker] Setting machine config: #{vcpu_count} vCPUs, #{mem_size_mib} MiB RAM")
    body = %{
      vcpu_count: vcpu_count,
      mem_size_mib: mem_size_mib,
      smt: false
    }
    put_request(socket_path, "/machine-config", body)
  end

  @doc """
  Starts the microVM.
  """
  def start_vm(socket_path) do
    Logger.info("[Sandbox.Firecracker] Starting VM")
    put_request(socket_path, "/actions", %{action_type: "InstanceStart"})
  end

  @doc """
  Sets the MMDS metadata for the VM.
  """
  def set_metadata(socket_path, metadata) do
    Logger.info("[Sandbox.Firecracker] Setting MMDS metadata")
    put_request(socket_path, "/mmds", metadata)
  end

  defp put_request(socket_path, path, body) do
    if System.get_env("KARYON_MOCK_HARDWARE") == "1" do
      Logger.debug("[Sandbox.Firecracker] MOCK: PUT #{path} to #{socket_path}")
      :ok
    else
      # Use Mint for HTTP over Unix Domain Sockets
      # Ensure socket path exists before connecting
      if File.exists?(socket_path) do
        case Mint.HTTP.connect(:http, {:local, socket_path}, 0, hostname: "localhost") do
          {:ok, conn} ->
            json_body = Jason.encode!(body)
            headers = [{"content-type", "application/json"}]
            
            case Mint.HTTP.request(conn, "PUT", path, headers, json_body) do
              {:ok, conn, request_ref} ->
                receive_response(conn, request_ref)
              {:error, _conn, reason} ->
                {:error, reason}
            end
          {:error, reason} ->
            {:error, reason}
        end
      else
        {:error, :socket_not_found}
      end
    end
  end

  defp receive_response(conn, request_ref) do
    receive do
      {:tcp, _, _} = msg ->
        case Mint.HTTP.stream(conn, msg) do
          {:ok, conn, responses} ->
            handle_responses(conn, request_ref, responses)
          {:error, _conn, reason, _responses} ->
            {:error, reason}
        end
    after
      5000 -> {:error, :timeout}
    end
  end

  defp handle_responses(_conn, request_ref, responses) do
    Enum.find_value(responses, fn
      {:status, ^request_ref, status} when status in 200..299 -> :ok
      {:status, ^request_ref, status} -> {:error, {:status, status}}
      {:error, ^request_ref, reason} -> {:error, reason}
      _ -> nil
    end) || {:error, :no_status_received}
  end
end
