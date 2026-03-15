defmodule NervousSystem.EndocrineGradientTest do
  use ExUnit.Case, async: false
  require Logger

  alias NervousSystem.Endocrine
  alias NervousSystem.Protos.MetabolicSpike

  test "broadcasts metabolic spikes to multiple cellular subscribers via NATS" do
    topic = "test.metabolic.spike"
    
    # Check if NATS is available, otherwise skip
    case Endocrine.get_gnat() do
      nil -> 
        Logger.warning("Skipping EndocrineGradientTest: NATS (:endocrine_gnat) not available")
        :ok
      gnat_pid ->
        # Create multiple subscribers
        subscribers = for i <- 1..5 do
          Task.async(fn ->
            # Each task acts as a cell subscribing to the spike
            Endocrine.subscribe(gnat_pid, topic)
            receive do
              {:msg, %{topic: ^topic, body: payload}} -> 
                decoded = MetabolicSpike.decode(payload)
                {:ok, i, decoded}
            after
              5000 -> {:error, i, :timeout}
            end
          end)
        end

        # Wait a bit for NATS subscriptions to propagate
        Process.sleep(200)

        # Publish a spike
        spike = MetabolicSpike.new(severity: "high", source: "metabolic_daemon")
        payload = MetabolicSpike.encode(spike)
        Endocrine.publish_gradient(gnat_pid, topic, payload)

        # Collect results
        results = Enum.map(subscribers, &Task.await/1)

        for {status, id, payload} <- results do
          assert status == :ok, "Subscriber #{id} timed out"
          assert payload.severity == "high"
        end
    end
  end
end
