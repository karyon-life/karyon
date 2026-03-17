defmodule Sandbox.Firecracker do
  @moduledoc """
  Low-level API wrapper for the AWS Firecracker microVM engine.
  Handles socket communication and VMM configuration using HTTP over UDS.
  """
  require Logger
  import Bitwise

  @doc """
  Resolves the host-side Firecracker runtime prerequisites.
  """
  def boot_requirements do
    with {:ok, binary_path} <- firecracker_binary_path(),
         {:ok, kernel_path} <- boot_asset_path(:kernel_image_path, "KARYON_FIRECRACKER_KERNEL", :kernel_image_not_found),
         {:ok, rootfs_path} <- boot_asset_path(:rootfs_path, "KARYON_FIRECRACKER_ROOTFS", :rootfs_image_not_found) do
      {:ok,
       %{
         binary_path: binary_path,
         kernel_image_path: kernel_path,
         rootfs_path: rootfs_path
       }}
    end
  end

  @doc """
  Initializes a Firecracker VMM via the control socket.
  """
  def init_vmm(socket_path) do
    Logger.info("[Sandbox.Firecracker] Initializing VMM at #{socket_path}")
    request(socket_path, "GET", "/version")
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
    request(socket_path, "PUT", "/boot-source", body)
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
    request(socket_path, "PUT", "/drives/#{drive_id}", body)
  end

  @doc """
  Configures a network interface.
  """
  def set_network_interface(socket_path, iface_id, host_dev_name) do
    Logger.info("[Sandbox.Firecracker] Setting network interface #{iface_id}: #{host_dev_name}")
    body = %{
      iface_id: iface_id,
      host_dev_name: host_dev_name
    }
    request(socket_path, "PUT", "/network-interfaces/#{iface_id}", body)
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
    request(socket_path, "PUT", "/machine-config", body)
  end

  @doc """
  Starts the microVM.
  """
  def start_vm(socket_path) do
    Logger.info("[Sandbox.Firecracker] Starting VM")
    request(socket_path, "PUT", "/actions", %{action_type: "InstanceStart"})
  end

  @doc """
  Sets the MMDS metadata for the VM.
  """
  def set_metadata(socket_path, metadata) do
    Logger.info("[Sandbox.Firecracker] Setting MMDS metadata")
    request(socket_path, "PUT", "/mmds", metadata)
  end

  defp firecracker_binary_path do
    candidates = [
      Application.get_env(:sandbox, :firecracker_binary),
      System.get_env("KARYON_FIRECRACKER_BINARY"),
      System.find_executable("firecracker")
    ]

    case Enum.find(candidates, &valid_executable?/1) do
      nil -> {:error, :firecracker_binary_not_found}
      path -> {:ok, path}
    end
  end

  defp boot_asset_path(config_key, env_key, error_atom) do
    candidates = [
      Application.get_env(:sandbox, config_key),
      System.get_env(env_key)
    ]

    case Enum.find(candidates, &valid_file?/1) do
      nil -> {:error, error_atom}
      path -> {:ok, Path.expand(path)}
    end
  end

  defp valid_executable?(path) when is_binary(path) do
    File.regular?(path) and executable?(path)
  end

  defp valid_executable?(_path), do: false

  defp valid_file?(path) when is_binary(path), do: File.regular?(path)
  defp valid_file?(_path), do: false

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} -> (mode &&& 0o111) != 0
      _ -> false
    end
  end

  defp request(socket_path, method, path, body \\ nil) do
    if System.get_env("KARYON_MOCK_HARDWARE") in ["1", "true"] do
      Logger.debug("[Sandbox.Firecracker] MOCK: #{method} #{path} to #{socket_path}")
      :ok
    else
      # Use Mint for HTTP over Unix Domain Sockets
      # Ensure socket path exists before connecting
      if File.exists?(socket_path) do
        case Mint.HTTP.connect(:http, {:local, socket_path}, 0, hostname: "localhost") do
          {:ok, conn} ->
            {headers, payload} = request_payload(body)
            
            case Mint.HTTP.request(conn, method, path, headers, payload) do
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

  defp request_payload(nil), do: {[], nil}

  defp request_payload(body) do
    {[{"content-type", "application/json"}], Jason.encode!(body)}
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
