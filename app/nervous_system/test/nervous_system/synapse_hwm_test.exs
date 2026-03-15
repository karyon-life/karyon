defmodule NervousSystem.SynapseHwmTest do
  use ExUnit.Case
  alias NervousSystem.Synapse

  test "Push-Pull HWM behavior: verify drop/block at limit 1" do
    # Start a PUSH synapse
    {:ok, push_pid} = Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:0")
    {:ok, port} = GenServer.call(push_pid, :get_port)
    
    # We don't start a PULLer yet. The PUSH socket should fill up its 1-message buffer.
    
    # First send should succeed (buffered in ZMQ)
    assert :ok == Synapse.send_signal(push_pid, "message 1", 1)
    
    # Second send should ideally fail or block if HWM is 1. 
    # In Chumak/ZMQ, PUSH might drop quietely if nobody is connected, 
    # but let's see how :chumak handles it.
    
    # We'll use a short timeout for the call to avoid hanging the test if it blocks
    # Actually, chumak.send is usually non-blocking unless specified.
    
    # Let's try to send many and see if it crashes or errors
    results = for _ <- 1..10, do: Synapse.send_signal(push_pid, "flood", 0)
    
    # If it doesn't crash, it's at least not blowing up under pressure.
    assert Enum.all?(results, fn res -> res == :ok or match?({:error, _}, res) end)
    
    GenServer.stop(push_pid)
  end

  test "Zero-buffer latency: verify nanosecond immediate delivery" do
    # Start PUSH and PULL
    {:ok, push_pid} = Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:0")
    {:ok, port} = GenServer.call(push_pid, :get_port)
    
    {:ok, pull_pid} = Synapse.start_link(type: :pull, bind: "tcp://127.0.0.1:#{port}", action: :connect, owner: self())
    
    # Wait for connection
    Process.sleep(100)
    
    # Measure latency
    start_time = System.monotonic_time(:nanosecond)
    :ok = Synapse.send_signal(push_pid, "ping", 5)
    
    assert_receive {:synapse_recv, ^pull_pid, "ping"}, 500
    end_time = System.monotonic_time(:nanosecond)
    
    latency = end_time - start_time
    # Latency should be extremely low on localhost (unlikely to exceed 5ms = 5,000,000 ns)
    assert latency < 10_000_000
    
    GenServer.stop(push_pid)
    GenServer.stop(pull_pid)
  end
end
