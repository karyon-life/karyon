defmodule NervousSystem.Endocrine do
  @moduledoc """
  Global ambient telemetry broadcaster via NATS Core (Gnat).
  Represents endocrine gradients tracking holistic cluster starvation.
  """

  @doc """
  Connects to the global NATS network.
  """
  def start_connection(_client_id, url \\ nil) do
    url
    |> service_url()
    |> connection_options()
    |> Gnat.start_link()
  end

  @doc """
  Broadcasts an ambient metabolic pressure signal to the cluster.
  """
  def publish_gradient(gnat, topic, payload) do
    Gnat.pub(gnat, topic, payload)
  end

  @doc """
  Subscribes the current process to an endocrine gradient topic.
  """
  def subscribe(gnat, topic) do
    case Gnat.sub(gnat, self(), topic) do
      {:ok, _id} -> :ok
      err -> err
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
end
