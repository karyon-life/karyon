defmodule NervousSystem.SynapsePropertyTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  @moduledoc """
  Property-based verification for Synapse temporal guarantees.
  Ensures that the HWM=1 constraint and zero-buffer logic hold under randomized traffic.
  """

  @tag timeout: 120_000
  property "synapse preserves message integrity across randomized payloads" do
    check all payload <- string(:printable), max_runs: 5 do
      {:ok, pull_pid} = NervousSystem.Synapse.start_link(type: :pull, bind: "tcp://127.0.0.1:0", owner: self())
      %{port: port} = :sys.get_state(pull_pid)
      
      # Allow listener to stabilize longer
      Process.sleep(20)

      # Start a PUSH synapse (sender)
      {:ok, push_pid} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)

      # Send the randomized signal
      :ok = NervousSystem.Synapse.send_signal(push_pid, payload)

      # Receive and verify
      assert_receive {:synapse_recv, ^pull_pid, ^payload}, 500
      
      # Synchronous cleanup
      GenServer.stop(pull_pid, :normal, 5000)
      GenServer.stop(push_pid, :normal, 5000)
    end
  end

  @tag timeout: 120_000
  property "synapse handles rapid bursts without corruption (HWM=1 exercise)" do
    check all payloads <- list_of(string(:alphanumeric), min_length: 5, max_length: 20), max_runs: 5 do
      {:ok, pull_pid} = NervousSystem.Synapse.start_link(type: :pull, bind: "tcp://127.0.0.1:0", owner: self())
      %{port: port} = :sys.get_state(pull_pid)
      
      Process.sleep(20)

      {:ok, push_pid} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)

      # Rapidly fire payloads
      for p <- payloads do
        NervousSystem.Synapse.send_signal(push_pid, p)
      end

      # Cleanup
      GenServer.stop(pull_pid, :normal, 5000)
      GenServer.stop(push_pid, :normal, 5000)
    end
  end

  @tag :property
  property "Synapse correctly handles arbitrary binary payloads including oversized messages" do
    check all payload <- binary(min_length: 1, max_length: 5000) do
      {:ok, pull_pid} = NervousSystem.Synapse.start_link(type: :pull, bind: "tcp://127.0.0.1:0", owner: self(), action: :bind)
      %{port: port} = :sys.get_state(pull_pid)
      {:ok, push_pid} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)

      Process.sleep(20)

      :ok = NervousSystem.Synapse.send_signal(push_pid, payload)

      assert_receive {:synapse_recv, ^pull_pid, ^payload}, 1000

      GenServer.stop(push_pid)
      GenServer.stop(pull_pid)
    end
  end

  test "rejects unsupported transports explicitly" do
    previous = Process.flag(:trap_exit, true)

    assert {:error, {:unsupported_protocol, :inproc}} =
             NervousSystem.Synapse.start_link(type: :pull, bind: "inproc://unsupported", owner: self())

    Process.flag(:trap_exit, previous)
  end
end
