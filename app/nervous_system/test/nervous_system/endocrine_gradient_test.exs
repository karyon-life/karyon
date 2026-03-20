defmodule NervousSystem.EndocrineGradientTest do
  use ExUnit.Case, async: false
  @moduletag :external
  require Logger

  alias NervousSystem.Endocrine

  setup_all do
    case Endocrine.start_connection("gradient_test") do
      {:ok, pid} ->
        on_exit(fn ->
          if Process.alive?(pid), do: GenServer.stop(pid)
          if Process.whereis(:endocrine_gnat) == pid, do: Process.unregister(:endocrine_gnat)
        end)

        if is_nil(Process.whereis(:endocrine_gnat)), do: Process.register(pid, :endocrine_gnat)
        {:ok, gnat_pid: pid}

      {:error, reason} ->
        {:ok, skip: "NATS broker unavailable for gradient integration test: #{inspect(reason)}"}
    end
  end

  test "broadcasts metabolic spikes to multiple cellular subscribers via NATS", %{gnat_pid: gnat_pid} do
    topic = "test.metabolic.spike"

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
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: 1.0, metric_type: "metabolic_daemon", source: "metabolic_daemon"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    Endocrine.publish_gradient(gnat_pid, topic, payload)

    # Collect results
    results = Enum.map(subscribers, &Task.await/1)

    for {status, id, res} <- results do
      assert status == :ok, "Subscriber #{id} timed out"
      assert {:ok, payload} = res
      assert_in_delta payload.severity, 1.0, 0.0001
    end
  end
end
