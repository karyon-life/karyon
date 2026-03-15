defmodule NervousSystem.SynapseStressTest do
  use ExUnit.Case, async: false
  require Logger

  alias NervousSystem.Synapse

  @msg_count 10_000

  test "floods push/pull synapse with high-frequency signals" do
    # Spawn receiver task to collect messages
    receiver_task = Task.async(fn ->
      receive_loop(self(), @msg_count, [])
    end)
    
    # Start Pull Synapse (Receiver) with dynamic port
    {:ok, pull_pid} = Synapse.start_link(type: :pull, bind: "tcp://127.0.0.1:0", owner: receiver_task.pid)
    
    # Get the assigned port
    {:ok, port} = GenServer.call(pull_pid, :get_port)

    # Start Push Synapse (Sender)
    {:ok, push_pid} = Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)

    # Allow time for connection
    Process.sleep(200)

    # Start sending messages as fast as possible
    start_time = System.monotonic_time(:millisecond)
    
    for i <- 1..@msg_count do
      Synapse.send_signal(push_pid, "msg_#{i}")
    end

    # Wait for all messages to be received
    received_msgs = Task.await(receiver_task, 30_000)
    end_time = System.monotonic_time(:millisecond)

    duration = end_time - start_time
    Logger.info("[StressTest] Sent #{@msg_count} messages in #{duration}ms (#{@msg_count / (duration / 1000)} msg/s)")

    assert length(received_msgs) == @msg_count
    # Verify ordering
    assert received_msgs == Enum.map(1..@msg_count, &"msg_#{&1}")
  end

  defp receive_loop(_tester, 0, acc), do: Enum.reverse(acc)
  defp receive_loop(tester, count, acc) do
    receive do
      {:synapse_recv, _pid, payload} ->
        receive_loop(tester, count - 1, [payload | acc])
    after
      10000 -> 
        Logger.error("Timeout after receiving #{length(acc)} messages (needed #{count} more)")
        Enum.reverse(acc)
    end
  end
end
