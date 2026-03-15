defmodule NervousSystem.SynapsePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias NervousSystem.Synapse

  @tag :property
  property "Synapse correctly delivers arbitrary binary payloads with integrity" do
    check all payload <- binary(min_length: 1, max_length: 1024) do
      # Back to tcp since chumak doesn't support inproc
      addr = "tcp://127.0.0.1:0"
      
      {:ok, pull_pid} = Synapse.start_link(type: :pull, bind: addr, owner: self(), action: :bind)
      {:ok, %{port: port}} = {:ok, :sys.get_state(pull_pid)}
      {:ok, push_pid} = Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)

      Process.sleep(20)

      :ok = Synapse.send_signal(push_pid, payload)

      assert_receive {:synapse_recv, ^pull_pid, ^payload}, 1000

      GenServer.stop(push_pid)
      GenServer.stop(pull_pid)
    end
  end

  @tag :property
  property "Synapse rejects or handles oversized messages according to SPEC" do
    check all payload <- binary(min_length: 1025, max_length: 5000) do
      addr = "tcp://127.0.0.1:0"
      
      {:ok, pull_pid} = Synapse.start_link(type: :pull, bind: addr, owner: self())
      {:ok, %{port: port}} = {:ok, :sys.get_state(pull_pid)}
      {:ok, push_pid} = Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)

      Process.sleep(20)

      :ok = Synapse.send_signal(push_pid, payload)

      assert_receive {:synapse_recv, ^pull_pid, ^payload}, 1000

      GenServer.stop(push_pid)
      GenServer.stop(pull_pid)
    end
  end
end
