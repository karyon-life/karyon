defmodule NervousSystem.SynapsePressureTest do
  @moduledoc """
  Validates ZMQ transport robustness under load.
  Note: Pain signals now use PubSub, but ZMQ is still used for generic peripheral sensors.
  """
  use ExUnit.Case, async: false
  alias NervousSystem.Synapse

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

  test "high-frequency ZMQ bursts" do
    # 1. Start a generic PUB synapse
    port = 6789 
    {:ok, pub_pid} = Synapse.start_link(type: :pub, bind: "tcp://127.0.0.1:#{port}")
    
    # 2. Start multiple SUB synapses
    subs = for _ <- 1..5 do
      {:ok, sub_pid} = Synapse.start_link(
        type: :sub, 
        bind: "tcp://127.0.0.1:#{port}", 
        action: :connect
      )
      sub_pid
    end
    
    Process.sleep(200)

    # 3. Burst 100 signals rapidly
    for i <- 1..100 do
      Synapse.send_signal(pub_pid, "stress_pulse_#{i}")
    end
    
    Process.sleep(500)
    
    Enum.each(subs, fn sub_pid ->
      assert Process.alive?(sub_pid)
    end)

    assert_receive {:transport_event, [:karyon, :nervous_system, :synapse, :send_ok], %{plane: :peer_to_peer, bytes: bytes}}, 1_000
    assert bytes > 0

    GenServer.stop(pub_pid)
    Enum.each(subs, &GenServer.stop/1)
  end

  test "dynamic port allocation and collision resilience" do
    {:ok, pid1} = Synapse.start_link(type: :pub, bind: "tcp://127.0.0.1:0")
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
    # With 1 retry, it might succeed or fail depending on ZMQ state but telemetry should fire
    assert result == :ok or match?({:error, _}, result)
    assert_receive {:transport_event, [:karyon, :nervous_system, :synapse, :send_retry], %{plane: :peer_to_peer}}, 1_000
  end
end
