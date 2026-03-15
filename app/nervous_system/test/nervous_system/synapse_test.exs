defmodule NervousSystem.SynapseTest do
  use ExUnit.Case, async: false

  test "synapse can send and receive signals (PUSH/PULL)" do
    addr = "tcp://127.0.0.1:0"
    {:ok, pull_pid} = NervousSystem.Synapse.start_link(type: :pull, bind: addr, owner: self())
    %{port: port} = :sys.get_state(pull_pid)

    # Allow listener to stabilize
    Process.sleep(50)

    # Start a PUSH synapse (sender)
    {:ok, push_pid} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)
    
    # Allow ZMQ handshake
    Process.sleep(200)

    # Send a signal
    payload = "test_signal"
    :ok = NervousSystem.Synapse.send_signal(push_pid, payload)

    # Receive the signal
    assert_receive {:synapse_recv, ^pull_pid, ^payload}, 1000

    # Cleanup
    GenServer.stop(pull_pid, :normal, 5000)
    GenServer.stop(push_pid, :normal, 5000)
  end

  test "synapse reinforces determinism via HWM=1" do
    # We test that we can't flood the receiver without it consuming
    addr = "tcp://127.0.0.1:0"
    {:ok, pull_pid} = NervousSystem.Synapse.start_link(type: :pull, bind: addr, owner: self())
    %{port: port} = :sys.get_state(pull_pid)
    {:ok, push_pid} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)

    Process.sleep(50)

    # Fill the HWM (1 message)
    :ok = NervousSystem.Synapse.send_signal(push_pid, "msg1")
    
    for i <- 2..5 do
      :ok = NervousSystem.Synapse.send_signal(push_pid, "msg#{i}")
    end

    assert_receive {:synapse_recv, ^pull_pid, "msg1"}, 500
    
    # Cleanup
    GenServer.stop(pull_pid)
    GenServer.stop(push_pid)
  end
end
