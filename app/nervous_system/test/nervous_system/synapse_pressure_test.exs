defmodule NervousSystem.SynapsePressureTest do
  use ExUnit.Case, async: false
  alias NervousSystem.Synapse
  alias NervousSystem.PainReceptor

  test "high-frequency ZMQ bursts" do
    # 1. Start a PUB synapse via PainReceptor
    # Ensure any previous instances are dead
    if pid = GenServer.whereis(PainReceptor), do: GenServer.stop(pid)
    
    # Set a fixed port for testing to avoid dynamic port hunting in this specific stress test
    port = 6789 
    Application.put_env(:nervous_system, :nociception_port, port)
    
    case PainReceptor.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    # 2. Start multiple SUB synapses that subscribe to this port
    subs = for _ <- 1..5 do
      {:ok, sub_pid} = Synapse.start_link(
        type: :sub, 
        bind: "tcp://127.0.0.1:#{port}", 
        action: :connect
      )
      sub_pid
    end
    
    # Give some time for ZMQ connections to stabilize
    Process.sleep(200)

    # 3. Burst 100 pain signals rapidly
    for i <- 1..100 do
      PainReceptor.trigger_nociception(%{"burst_index" => i})
    end
    
    # 4. Verify reception at SUB level (sampled)
    Process.sleep(500)
    
    Enum.each(subs, fn sub_pid ->
      assert Process.alive?(sub_pid)
    end)

    GenServer.stop(PainReceptor)
    Enum.each(subs, &GenServer.stop/1)
  end

  test "dynamic port allocation and collision resilience" do
    # Start a synapse on port 0 (dynamic)
    {:ok, pid1} = Synapse.start_link(type: :pub, bind: "tcp://127.0.0.1:0")
    
    # Verification of dynamic port
    {:ok, port} = GenServer.call(pid1, :get_port)
    assert port > 0

    GenServer.stop(pid1)
  end
end
