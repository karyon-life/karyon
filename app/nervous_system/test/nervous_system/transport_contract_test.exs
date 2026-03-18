defmodule NervousSystem.TransportContractTest do
  use ExUnit.Case, async: false

  alias NervousSystem.{Endocrine, Synapse}

  test "synapse declares the peer-to-peer ZeroMQ plane" do
    descriptor = Synapse.transport_descriptor()

    assert descriptor.plane == :peer_to_peer
    assert descriptor.transport == :zmq
    assert descriptor.topology == :peer_to_peer
    assert descriptor.queue_semantics == :bounded_hwm
    assert :push in descriptor.roles
    assert :pull in descriptor.roles
  end

  test "endocrine declares the global NATS control plane" do
    descriptor = Endocrine.transport_descriptor()

    assert descriptor.plane == :global_control
    assert descriptor.transport == :nats
    assert descriptor.topology == :global_broadcast
    assert descriptor.queue_semantics == :broker_controlled
    assert :publish_gradient in descriptor.roles
    assert :subscribe in descriptor.roles
  end

  test "synapse exposes queryable runtime transport state" do
    {:ok, pid} = Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:0", hwm: 7)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    assert {:ok, state} = GenServer.call(pid, :transport_state)
    assert state.plane == :peer_to_peer
    assert state.transport == :zmq
    assert state.queue_semantics == :bounded_hwm
    assert state.hwm == 7
    assert state.action == :bind
    assert state.type == :push
  end
end
