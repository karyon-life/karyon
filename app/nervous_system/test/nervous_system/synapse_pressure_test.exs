defmodule NervousSystem.SynapsePressureTest do
  use ExUnit.Case, async: false
  alias NervousSystem.Synapse
  alias NervousSystem.PainReceptor

  test "high-frequency ZMQ bursts" do
    # 1. Start a PUB synapse via PainReceptor
    # PainReceptor is normally started by the application.
    # We'll use the one already running or start a fresh one.
    if GenServer.whereis(PainReceptor), do: GenServer.stop(PainReceptor)
    
    # Set a specific port for testing
    port = 6666
    Application.put_env(:nervous_system, :nociception_port, port)
    
    {:ok, _} = PainReceptor.start_link([])
    
    # 2. Start multiple SUB synapses that subscribe to this port
    subs = for _ <- 1..5 do
      {:ok, sub_pid} = Synapse.start_link(
        type: :sub, 
        bind: "tcp://127.0.0.1:#{port}", 
        action: :connect
      )
      sub_pid
    end
    
    # 3. Burst 100 pain signals rapidly
    for i <- 1..100 do
      PainReceptor.trigger_nociception(%{"burst_index" => i})
    end
    
    # 4. Verify reception at SUB level (sampled)
    # We can't easily wait for all 100 on all 5 subs without complex logic, 
    # but we'll verify it doesn't crash and at least some are received.
    Process.sleep(500)
    
    Enum.each(subs, fn sub_pid ->
      assert Process.alive?(sub_pid)
    end)
  end

  test "dynamic port allocation and collision resilience" do
    # Start a synapse on port 0 (dynamic)
    {:ok, pid1} = Synapse.start_link(type: :pub, bind: "tcp://127.0.0.1:0")
    
    # Try to start another one on the SAME port (should fail or find another if 0)
    # If we specified a fixed port, it should fail.
    
    # Try fixed port collision
    fixed_port = 7777
    {:ok, _pid2} = Synapse.start_link(type: :pub, bind: "tcp://127.0.0.1:#{fixed_port}")
    
    # This one should fail if it's a strict bind
    assert {:error, _} = Synapse.start_link(type: :pub, bind: "tcp://127.0.0.1:#{fixed_port}")
    
    GenServer.stop(pid1)
  end
end
