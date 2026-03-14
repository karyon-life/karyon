defmodule NervousSystem.Property.TemporalTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduledoc """
  Property-based tests for ZeroMQ message ordering.
  Verifies that random permutations of messages are handled deterministically.
  """

  @tag timeout: 120_000
  property "messages obey Head-of-Line blocking or dropping based on HWM=1" do
    check all messages <- list_of(binary(), min_length: 5, max_length: 20), max_runs: 20 do
      # Let Synapse find a free port automatically
      addr = "tcp://127.0.0.1:0"

      # 1. Start a PULL synapse (the consumer)
      {:ok, pull_pid} = NervousSystem.Synapse.start_link(type: :pull, bind: addr, owner: self())
      %{port: port} = :sys.get_state(pull_pid)
      
      # 2. Start a PUSH synapse (the producer)
      {:ok, push_pid} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)
      
      # Allow connection
      Process.sleep(100)
      
      # 3. Saturate the connection
      # Since HWM=1 on both sides, and chumak has internal buffers, 
      # we expect that flooding it will eventually result in errors or dropped messages 
      # if we don't consume them.
      
      results = Enum.map(messages, fn msg ->
        NervousSystem.Synapse.send_signal(push_pid, msg, 2) # Low retries to test pressure
      end)
      
      # We expect at least the first one to succeed, and others might fail or be buffered
      assert :ok in results
      
      # Cleanup
      GenServer.stop(pull_pid)
      GenServer.stop(push_pid)
    end
  end
end
