defmodule NervousSystem.PainReceptorTest do
  use ExUnit.Case, async: false

  setup do
    case NervousSystem.PainReceptor.start_link([]) do
      {:ok, pid} ->
        on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
        {:ok, pid: pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid: pid}
    end
  end

  test "intercepts telemetry error and sends nociception signal" do
    # 1. Listen for Synapse signals
    # The PainReceptor binds to a specific port. 
    # Let's check which port it uses in test env (usually 5555 from default).
    port = Application.get_env(:nervous_system, :nociception_port, 5555)
    
    # Start a SUB synapse to verify the PainReceptor's PUB broadcast
    {:ok, sub_pid} = NervousSystem.Synapse.start_link(
      type: :sub, 
      bind: "tcp://127.0.0.1:#{port}", 
      action: :connect,
      owner: self()
    )
    
    # Subscribe to all messages (empty string topic)
    :ok = GenServer.call(sub_pid, {:subscribe, ""})

    # 2. Give ZMQ SUB time to connect to the PUB socket (slow joiner problem)
    Process.sleep(200)

    # 3. Trigger a simulated "Pain" event via Telemetry
    metadata = %{reason: "crash", module: __MODULE__}
    :telemetry.execute([:logger, :error], %{count: 1}, metadata)

    # 4. Assert signal arrival
    assert_receive {:synapse_recv, ^sub_pid, payload}, 2000
    
    decoded = Jason.decode!(payload)
    assert decoded["type"] == "nociception"
    assert decoded["metadata"]["reason"] == "\"crash\""
  end
end
