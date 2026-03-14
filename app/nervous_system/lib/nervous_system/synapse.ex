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

  def send_signal(pid, payload) do
    GenServer.call(pid, {:send, payload})
  end

  @impl true
  def init(opts) do
    type = Keyword.get(opts, :type, :push)
    bind_addr = Keyword.get(opts, :bind, "tcp://127.0.0.1:0")
    owner = Keyword.get(opts, :owner, self())

    {:ok, socket_pid} = :chumak.socket(type)
    
    # Strictly cap the buffer to enforce physical pain/prediction errors during saturation.
    :chumak.set_socket_option(socket_pid, :sndhwm, 1)
    :chumak.set_socket_option(socket_pid, :rcvhwm, 1)

    # Simple parsing logic
    [protocol, rest] = String.split(bind_addr, "://")
    [host, port_str] = String.split(rest, ":")
    port = String.to_integer(port_str)

    case :chumak.bind(socket_pid, String.to_atom(protocol), ~c"#{host}", port) do
      {:ok, bound_port} ->
        Logger.info("[Synapse] Bound to #{protocol}://#{host}:#{bound_port}")
        # If it's a receiver type (SUB, PULL), we should start a polling loop
        if type in [:sub, :pull] do
          send(self(), :poll_socket)
        end
        {:ok, %{socket: socket_pid, port: bound_port, type: type, owner: owner}}
      {:error, reason} ->
        {:stop, reason}
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
  def handle_info(:poll_socket, state) do
    case :chumak.recv(state.socket) do
      {:ok, payload} ->
        send(state.owner, {:synapse_recv, self(), payload})
      _ ->
        :ok
    end
    # Short poll interval to simulate real-time synaptic firing
    Process.send_after(self(), :poll_socket, 10)
    {:noreply, state}
  end
end
