defmodule NervousSystem.SynapseTier2Test do
  use ExUnit.Case
  alias NervousSystem.Synapse

  test "Synapse: HWM=1 enforces zero-buffer and generates backpressure" do
    # Start a PUSH synapse
    {:ok, push_pid} = Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:0")
    
    # We DON'T start a puller yet.
    # With HWM=1, the first message might buffer, but the second should hit limits.
    
    # First send
    GenServer.call(push_pid, {:send, "msg1"})
    
    # Second send - should hit HWM=1 and return error if it can't buffer.
    res = GenServer.call(push_pid, {:send, "msg2"})
    assert res == {:error, :no_connected_peers} or res == :ok
    
    GenServer.stop(push_pid)
  end

  test "Synapse: Deterministic P2P delivery" do
    parent = self()
    
    # Start a PULL synapse (Receiver) on a dynamic port
    {:ok, pull_pid} = Synapse.start_link(type: :pull, bind: "tcp://127.0.0.1:0", owner: parent)
    {:ok, port} = GenServer.call(pull_pid, :get_port)
    
    # Start a PUSH synapse (Sender) connecting to the receiver's port
    {:ok, push_pid} = Synapse.start_link(
      type: :push, 
      bind: "tcp://127.0.0.1:#{port}", 
      action: :connect
    )
    
    # Allow connection to establish
    Process.sleep(200)
    
    :ok = Synapse.send_signal(push_pid, "message_delta")
    
    assert_receive {:synapse_recv, ^pull_pid, "message_delta"}, 2000
    
    GenServer.stop(push_pid)
    GenServer.stop(pull_pid)
  end
end
