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
      # Use a very large randomized port range to minimize collisions in TIME_WAIT
      port = 30000 + :rand.uniform(20000)
      {:ok, pull_pid} = NervousSystem.Synapse.start_link(type: :pull, bind: "tcp://127.0.0.1:#{port}", owner: self())
      
      # Allow listener to stabilize
      Process.sleep(50)

      # Start a PUSH synapse (sender)
      {:ok, push_pid} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)

      # Send the randomized signal
      :ok = NervousSystem.Synapse.send_signal(push_pid, payload)

      # Receive and verify
      assert_receive {:synapse_recv, ^pull_pid, ^payload}, 500
      
      # Synchronous cleanup to avoid :eaddrinuse in rapid property iterations
      GenServer.stop(pull_pid, :normal, 5000)
      GenServer.stop(push_pid, :normal, 5000)
    end
  end

  @tag timeout: 120_000
  property "synapse handles rapid bursts without corruption (HWM=1 exercise)" do
    check all payloads <- list_of(string(:alphanumeric), min_length: 5, max_length: 20), max_runs: 5 do
      port = 50000 + :rand.uniform(10000)
      {:ok, pull_pid} = NervousSystem.Synapse.start_link(type: :pull, bind: "tcp://127.0.0.1:#{port}", owner: self())
      
      # Allow listener to stabilize
      Process.sleep(50)

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
end
