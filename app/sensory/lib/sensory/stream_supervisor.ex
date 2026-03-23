defmodule Sensory.StreamSupervisor do
  @moduledoc """
  Supervises ZeroMQ sensory ingestion processes.
  """
  use GenServer
  alias Sensory.Native
  alias Sensory.Perimeter
  alias Sensory.TabulaRasa.Ingestor

  @default_subscriptions [
    %{organ: :tabula_rasa, surface: :continuous_byte_stream, transport: :zeromq, topic: "raw_bytes"},
    %{organ: :ears, surface: :tensor_stream, transport: :zeromq, topic: "neural_tensor"},
    %{organ: :ears, surface: :telemetry_event, transport: :zeromq, topic: "telemetry"},
    %{organ: :ears, surface: :log_line, transport: :zeromq, topic: "logs"},
    %{organ: :ears, surface: :webhook_payload, transport: :http, topic: "webhooks"}
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    subscriptions = Keyword.get(opts, :subscriptions, @default_subscriptions)

    with {:ok, validated_subscriptions} <- validate_subscriptions(subscriptions) do
      send(self(), :listen)
      {:ok, %{subscriptions: validated_subscriptions}}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:listen, state) do
    Enum.each(state.subscriptions, fn %{topic: topic} = subscription ->
      # This is a non-blocking check in the NIF with 1s timeout
      # In a real system, this would be a high-performance loop in Rust or a dedicated Actor
      case Native.zmq_subscribe_sensory(topic) do
        {:ok, payload} ->
          handle_payload(subscription, payload)
        {:error, _reason} ->
          :ok
      end
    end)

    # Schedule next check
    Process.send_after(self(), :listen, 100)
    {:noreply, state}
  end

  defp handle_payload(%{surface: :tensor_stream}, _payload) do
    # Tensor streams are now processed natively by the Rust peripheral boundary.
    # The resulting 64-bit integer tokens are emitted asynchronously to Sensory.NifRouter.
    :ok
  end

  defp handle_payload(%{surface: :continuous_byte_stream}, payload) when is_binary(payload) do
    _ = Ingestor.ingest_bytes(payload)
    :ok
  end

  defp handle_payload(%{surface: surface, transport: transport, topic: topic}, payload) do
    case Sensory.Ears.ingest_event(%{
           surface: surface,
           transport: transport,
           source: topic,
           payload: normalize_stream_payload(surface, payload)
         }) do
      {:ok, _event} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp validate_subscriptions(subscriptions) when is_list(subscriptions) do
    Enum.reduce_while(subscriptions, {:ok, []}, fn subscription, {:ok, acc} ->
      case Perimeter.validate_ingestion(subscription) do
        {:ok, _validated} ->
          normalized =
            subscription
            |> Map.new(fn {key, value} -> {key, value} end)
            |> Map.put_new(:topic, topic_for_surface(subscription))

          {:cont, {:ok, [normalized | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_subscriptions(_subscriptions), do: {:error, :invalid_subscription_list}

  defp topic_for_surface(subscription) do
    case Map.get(subscription, :topic) || Map.get(subscription, "topic") do
      nil ->
        case Map.get(subscription, :surface) || Map.get(subscription, "surface") do
          :tensor_stream -> "neural_tensor"
          "tensor_stream" -> "neural_tensor"
          :telemetry_event -> "telemetry"
          "telemetry_event" -> "telemetry"
          :log_line -> "logs"
          "log_line" -> "logs"
          :webhook_payload -> "webhooks"
          "webhook_payload" -> "webhooks"
          other -> to_string(other)
        end

      topic ->
        topic
    end
  end

  defp normalize_stream_payload(:telemetry_event, payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{} = decoded} -> decoded
      _ -> %{"event_name" => "telemetry", "metadata" => payload}
    end
  end

  defp normalize_stream_payload(:webhook_payload, payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{} = decoded} -> decoded
      _ -> %{"body" => payload}
    end
  end

  defp normalize_stream_payload(:log_line, payload), do: to_string(payload)
  defp normalize_stream_payload(_surface, payload), do: payload
end
