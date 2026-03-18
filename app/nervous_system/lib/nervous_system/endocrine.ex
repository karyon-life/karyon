defmodule NervousSystem.Endocrine do
  @moduledoc """
  Global ambient telemetry broadcaster via NATS Core (Gnat).
  Represents endocrine gradients tracking holistic cluster starvation.
  """

  @transport_plane :global_control
  @transport_roles [:publish_gradient, :subscribe]

  def transport_descriptor do
    %{
      plane: @transport_plane,
      roles: @transport_roles,
      transport: :nats,
      topology: :global_broadcast,
      queue_semantics: :broker_controlled
    }
  end

  @doc """
  Connects to the global NATS network.
  """
  def start_connection(client_id, url \\ nil) do
    resolved_url = service_url(url)

    case resolved_url |> connection_options() |> Gnat.start_link() do
      {:ok, _pid} = ok ->
        emit_transport_event(:connect_ok, %{client_id: to_string(client_id), url: resolved_url, plane: @transport_plane})
        ok

      {:error, reason} = error ->
        emit_transport_event(:connect_failed, %{client_id: to_string(client_id), url: resolved_url, plane: @transport_plane, reason: inspect(reason)})
        error
    end
  end

  @doc """
  Broadcasts an ambient metabolic pressure signal to the cluster.
  """
  def publish_gradient(gnat, topic, payload) do
    try do
      case Gnat.pub(gnat, topic, payload) do
        :ok = ok ->
          emit_transport_event(:publish_ok, %{topic: topic, plane: @transport_plane, bytes: payload_size(payload)})
          ok

        {:error, reason} = error ->
          emit_transport_event(:publish_failed, %{topic: topic, plane: @transport_plane, reason: inspect(reason), bytes: payload_size(payload)})
          error
      end
    catch
      :exit, reason ->
        emit_transport_event(:publish_failed, %{topic: topic, plane: @transport_plane, reason: inspect(reason), bytes: payload_size(payload)})
        {:error, reason}
    end
  end

  @doc """
  Subscribes the current process to an endocrine gradient topic.
  """
  def subscribe(gnat, topic) do
    try do
      case Gnat.sub(gnat, self(), topic) do
        {:ok, _id} ->
          emit_transport_event(:subscribe_ok, %{topic: topic, plane: @transport_plane})
          :ok

        err ->
          emit_transport_event(:subscribe_failed, %{topic: topic, plane: @transport_plane, reason: inspect(err)})
          err
      end
    catch
      :exit, reason ->
        emit_transport_event(:subscribe_failed, %{topic: topic, plane: @transport_plane, reason: inspect(reason)})
        {:error, reason}
    end
  end

  @doc """
  Returns the globally registered endocrine NATS PID if available.
  """
  def get_gnat() do
    Process.whereis(:endocrine_gnat)
  end

  defp service_url(nil) do
    :karyon
    |> Application.get_env(:services, [])
    |> Keyword.get(:nats, [])
    |> Keyword.get(:url, "nats://127.0.0.1:4222")
  end

  defp service_url(url), do: url

  defp connection_options(url) do
    uri = URI.parse(url)

    %{
      host: uri.host || "127.0.0.1",
      port: uri.port || 4222
    }
    |> maybe_put_credentials(uri.userinfo)
  end

  defp maybe_put_credentials(options, nil), do: options

  defp maybe_put_credentials(options, userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [username, password] ->
        options
        |> Map.put(:username, username)
        |> Map.put(:password, password)

      [username] ->
        Map.put(options, :username, username)
    end
  end

  defp emit_transport_event(event, metadata) do
    :telemetry.execute([:karyon, :nervous_system, :endocrine, event], %{}, metadata)
  end

  defp payload_size(payload) when is_binary(payload), do: byte_size(payload)
  defp payload_size(payload) when is_list(payload), do: IO.iodata_length(payload)
  defp payload_size(_payload), do: 0
end
