defmodule Sensory.StreamSupervisor do
  @moduledoc """
  Supervises ZeroMQ sensory ingestion processes.
  """
  use GenServer
  alias Sensory.Perimeter

  @default_subscriptions [
    %{organ: :tabula_rasa, surface: :continuous_byte_stream, transport: :zeromq, topic: "raw_bytes"}
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    subscriptions = Keyword.get(opts, :subscriptions, @default_subscriptions)

    with {:ok, validated_subscriptions} <- validate_subscriptions(subscriptions),
         {:ok, socket} <- :chumak.socket(:sub) do
      Enum.each(validated_subscriptions, fn %{topic: topic} ->
        :chumak.subscribe(socket, topic)
      end)
      
      # Connect to external sensors
      :chumak.connect(socket, :tcp, ~c"127.0.0.1", 5557)
      
      send(self(), :listen)
      {:ok, %{subscriptions: validated_subscriptions, socket: socket}}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:listen, state) do
    case :chumak.recv(state.socket) do
      {:ok, payload} ->
        # Asynchronously trigger BPE compression in the Rust NIF
        # This will emit :minted_token to Sensory.NifRouter
        _ = Sensory.PeripheralNif.compress_stream(self(), payload, 0.8, 5)
        :ok
      _ ->
        :ok
    end

    # Schedule next check
    Process.send_after(self(), :listen, 100)
    {:noreply, state}
  end


  defp validate_subscriptions(subscriptions) when is_list(subscriptions) do
    Enum.reduce_while(subscriptions, {:ok, []}, fn subscription, {:ok, acc} ->
      case Perimeter.validate_ingestion(subscription) do
        {:ok, _validated} ->
          normalized =
            subscription
            |> Map.new(fn {key, value} -> {key, value} end)
            |> Map.put_new(:topic, Map.get(subscription, :topic, "raw_bytes"))

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
end
