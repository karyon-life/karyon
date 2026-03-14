defmodule NervousSystem.Synapse do
  @moduledoc """
  Manages peer-to-peer data streaming using ZeroMQ (via :chumak).
  Enforces zero-buffer active inference determinism by severely capping message sizes and queues (HWM).
  """
  use GenServer
  require Logger

  @doc """
  Starts a Synaptic connection GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def send_signal(pid, payload, retries \\ 50) do
    case GenServer.call(pid, {:send, payload}) do
      {:error, :no_connected_peers} when retries > 0 ->
        Process.sleep(100)
        send_signal(pid, payload, retries - 1)
      res -> res
    end
  end

  @impl true
  def init(opts) do
    type = Keyword.get(opts, :type, :push)
    bind_addr = Keyword.get(opts, :bind, "tcp://127.0.0.1:0")
    owner = Keyword.get(opts, :owner, self())

    {:ok, socket_pid} = :chumak.socket(type)
    Process.link(socket_pid)
    
    # Strictly cap the buffer to enforce physical pain/prediction errors during saturation.
    :chumak.set_socket_option(socket_pid, :sndhwm, 1)
    :chumak.set_socket_option(socket_pid, :rcvhwm, 1)

    # Simple parsing logic
    [protocol, rest] = String.split(bind_addr, "://")
    [host, port_str] = String.split(rest, ":")
    port = String.to_integer(port_str)

    action = Keyword.get(opts, :action, :bind)

    case action do
      :bind ->
        case robust_bind(socket_pid, String.to_atom(protocol), host, port) do
          {:ok, bound_port_or_pid} ->
            Logger.info("[Synapse] Bound to #{protocol}://#{host}:#{inspect(bound_port_or_pid)}")
            if type in [:sub, :pull], do: start_receiver(socket_pid)
            {:ok, %{socket: socket_pid, port: bound_port_or_pid, type: type, owner: owner}}
          {:error, reason} -> {:stop, reason}
        end
      :connect ->
        case :chumak.connect(socket_pid, String.to_atom(protocol), ~c"#{host}", port) do
          {:ok, _conn_pid} ->
            Logger.info("[Synapse] Connected to #{protocol}://#{host}:#{port}")
            if type in [:sub, :pull], do: start_receiver(socket_pid)
            {:ok, %{socket: socket_pid, port: port, type: type, owner: owner}}
          {:error, reason} -> {:stop, reason}
        end
    end
  end

  defp robust_bind(socket, protocol, host, port, retries \\ 20) do
    case :chumak.bind(socket, protocol, ~c"#{host}", port) do
      {:ok, res} -> {:ok, res}
      {:error, :eaddrinuse} when retries > 0 ->
        # If we hit collision, try a different random port if was 0, or just retry if fixed
        new_port = if port == 0, do: 0, else: port + :rand.uniform(100)
        Process.sleep(50)
        robust_bind(socket, protocol, host, new_port, retries - 1)
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_receiver(socket_pid) do
    parent = self()
    spawn_link(fn ->
      receiver_loop(socket_pid, parent)
    end)
  end

  defp receiver_loop(socket_pid, parent) do
    case :chumak.recv(socket_pid) do
      {:ok, payload} ->
        send(parent, {:synapse_recv_internal, payload})
        receiver_loop(socket_pid, parent)
      {:error, _reason} ->
        :ok # Socket might be closed
    end
  end

  @impl true
  def handle_inner_send(socket, payload) do
     :chumak.send(socket, payload)
  end

  @impl true
  def handle_call({:send, payload}, _from, state) do
    case :chumak.send(state.socket, payload) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({:synapse_recv_internal, payload}, state) do
    send(state.owner, {:synapse_recv, self(), payload})
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if Map.has_key?(state, :socket) do
      # Chumak doesn't have a direct close, but letting the process die should clean up
      # or we can try to unbind if supported.
      :ok
    end
  end
end
