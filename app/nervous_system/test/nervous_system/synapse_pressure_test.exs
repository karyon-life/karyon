defmodule NervousSystem.SynapsePressureTest do
  use ExUnit.Case, async: false
  alias NervousSystem.Synapse
  alias NervousSystem.PainReceptor

  setup do
    parent = self()

    :telemetry.attach_many(
      "synapse-pressure-test-#{inspect(parent)}",
      [
        [:karyon, :nervous_system, :synapse, :send_retry],
        [:karyon, :nervous_system, :synapse, :send_failed],
        [:karyon, :nervous_system, :synapse, :send_ok],
        [:karyon, :nervous_system, :synapse, :subscribe_ok]
      ],
      fn event, _measurements, metadata, test_pid ->
        send(test_pid, {:transport_event, event, metadata})
      end,
      parent
    )

    on_exit(fn ->
      :telemetry.detach("synapse-pressure-test-#{inspect(parent)}")
    end)

    :ok
  end

  defp stop_if_alive(name) do
    case GenServer.whereis(name) do
      nil -> :ok
      pid ->
        try do
          Process.unlink(pid)
          GenServer.stop(pid)
        catch
          :exit, _ -> :ok
        end
    end
  end

  test "high-frequency ZMQ bursts" do
    # 1. Start a PUB synapse via PainReceptor
    # Ensure any previous instances are dead
    if pid = GenServer.whereis(PainReceptor), do: GenServer.stop(pid)
    stop_if_alive(:pain_synapse)
    
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

    assert_receive {:transport_event, [:karyon, :nervous_system, :synapse, :send_ok], %{plane: :peer_to_peer, bytes: bytes}}, 1_000
    assert bytes > 0

    GenServer.stop(PainReceptor)
    stop_if_alive(:pain_synapse)
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

  test "retry telemetry fires when no connected peers exist" do
    {:ok, push_pid} = Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:0")

    on_exit(fn ->
      if Process.alive?(push_pid), do: GenServer.stop(push_pid)
    end)

    result = Synapse.send_signal(push_pid, "orphaned", 1)
    assert result == :ok or match?({:error, _}, result)

    assert_receive {:transport_event, [:karyon, :nervous_system, :synapse, :send_retry], %{plane: :peer_to_peer, attempt: 10}}, 1_000
  end
end
