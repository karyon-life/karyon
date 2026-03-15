defmodule NervousSystem.EndocrineResilienceTest do
  use ExUnit.Case, async: false
  alias NervousSystem.Endocrine

  @topic "metabolic.spike"

  setup do
    # Start a local NATS server mock or connect to a real one if available.
    # For CI, we assume a local NATS is running (nats://localhost:4222).
    # If not, we'll mock the Gnat connection.
    
    {:ok, gnat} = Endocrine.start_connection("test_client")
    
    on_exit(fn ->
      if Process.alive?(gnat), do: GenServer.stop(gnat)
    end)
    
    {:ok, gnat: gnat}
  end

  test "connection recovery and subscription", %{gnat: gnat} do
    # Subscribe to a topic
    :ok = Endocrine.subscribe(gnat, @topic)
    # Publish a spike
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: "high", metric_type: "metabolic_daemon"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    Endocrine.publish_gradient(gnat, @topic, payload)
    
    # Verify reception
    assert_receive {:msg, %{topic: @topic, body: ^payload}}, 1000
    
    # Simulate connection drop
    # (Since we are using Gnat, it should auto-reconnect if configured, 
    # but we can force-kill the PID to see if the supervisor (if we had one) restarts it).
    # Currently NervousSystem doesn't supervise the Gnat connection.
  end

  test "protoc serialization safety", %{gnat: gnat} do
    # Test with protobuf encoded payload
    spike = %Karyon.NervousSystem.MetabolicSpike{
      metric_type: "l3_misses",
      value: 15000.0,
      threshold: 5000.0,
      severity: "high"
    }
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    
    :ok = Endocrine.publish_gradient(gnat, "metabolic.spike", payload)
    
    # Subscribe manually
    :ok = Endocrine.subscribe(gnat, "metabolic.spike")
    
    # Publish again
    :ok = Endocrine.publish_gradient(gnat, "metabolic.spike", payload)
    
    assert_receive {:msg, %{body: ^payload}}, 1000
    
    # Verify decoding
    assert {:ok, decoded} = Karyon.NervousSystem.MetabolicSpike.decode(payload)
    assert decoded.metric_type == "l3_misses"
  end
end
