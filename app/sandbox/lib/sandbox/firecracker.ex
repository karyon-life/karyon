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

  defp put_request(socket_path, path, body) do
    # Use Mint for HTTP over Unix Domain Sockets
    case Mint.HTTP.connect(:http, {:local, socket_path}, 0) do
      {:ok, conn} ->
        json_body = Jason.encode!(body)
        headers = [{"content-type", "application/json"}]
        
        case Mint.HTTP.request(conn, "PUT", path, headers, json_body) do
          {:ok, conn, request_ref} ->
            receive_response(conn, request_ref)
          {:error, conn, reason} ->
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp receive_response(conn, request_ref) do
    receive do
      {:tcp, _, _} = msg ->
        case Mint.HTTP.stream(conn, msg) do
          {:ok, _conn, responses} ->
            # Simple wrapper: just return :ok if status is 2xx
            if Enum.any?(responses, fn
              {:status, ^request_ref, status} when status in 200..299 -> true
              _ -> false
            end), do: :ok, else: {:error, :bad_status}
          _ ->
            {:error, :stream_fail}
        end
      _ ->
        {:error, :timeout}
    after
      5000 -> {:error, :timeout}
    end
  end
end
