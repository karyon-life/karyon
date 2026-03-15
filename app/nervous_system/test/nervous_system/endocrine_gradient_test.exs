defmodule NervousSystem.EndocrineGradientTest do
  use ExUnit.Case, async: false
  require Logger

  alias NervousSystem.Endocrine

  test "broadcasts metabolic spikes to multiple cellular subscribers via NATS" do
    topic = "test.metabolic.spike"
    
    # Ensure NATS connection is started
    gnat_pid = 
      case Endocrine.get_gnat() do
        nil -> 
          {:ok, pid} = Endocrine.start_connection("gradient_test")
          # Register it so get_gnat works later if needed
          if is_nil(Process.whereis(:endocrine_gnat)), do: Process.register(pid, :endocrine_gnat)
          pid
        pid -> pid
      end

    # Create multiple subscribers
    subscribers = for i <- 1..5 do
      Task.async(fn ->
        # Each task acts as a cell subscribing to the spike
        Endocrine.subscribe(gnat_pid, topic)
        receive do
          {:msg, %{topic: ^topic, body: payload}} -> 
            res = Karyon.NervousSystem.MetabolicSpike.decode(payload)
            {:ok, i, res}
        after
          5000 -> {:error, i, :timeout}
        end
      end)
    end

    # Wait a bit for NATS subscriptions to propagate
    Process.sleep(200)

    # Publish a spike
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: "high", metric_type: "metabolic_daemon"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    Endocrine.publish_gradient(gnat_pid, topic, payload)

    # Collect results
    results = Enum.map(subscribers, &Task.await/1)

    for {status, id, res} <- results do
      assert status == :ok, "Subscriber #{id} timed out"
      assert {:ok, payload} = res
      assert payload.severity == "high"
    end
  end
end
