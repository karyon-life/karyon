defmodule NervousSystem.EndocrineTest do
  use ExUnit.Case, async: false

  alias NervousSystem.Endocrine

  setup do
    parent = self()

    :telemetry.attach_many(
      "endocrine-test-#{inspect(parent)}",
      [
        [:karyon, :nervous_system, :endocrine, :connect_ok],
        [:karyon, :nervous_system, :endocrine, :connect_failed],
        [:karyon, :nervous_system, :endocrine, :publish_ok],
        [:karyon, :nervous_system, :endocrine, :publish_failed],
        [:karyon, :nervous_system, :endocrine, :subscribe_ok],
        [:karyon, :nervous_system, :endocrine, :subscribe_failed]
      ],
      fn event, _measurements, metadata, test_pid ->
        send(test_pid, {:endocrine_event, event, metadata})
      end,
      parent
    )

    on_exit(fn ->
      :telemetry.detach("endocrine-test-#{inspect(parent)}")
    end)

    :ok
  end

  # This test verifies the Endocrine dispatcher (NATS via Tortoise)
  # It requires an MQTT broker (simulating NATS for MVP) to be running or a mock.
  # For now, we'll verify it doesn't crash on start and can call publish.

  test "transport descriptor identifies the global NATS plane" do
    descriptor = Endocrine.transport_descriptor()

    assert descriptor.plane == :global_control
    assert descriptor.transport == :nats
    assert descriptor.topology == :global_broadcast
  end

  @tag :external
  test "endocrine connection attempt" do
    client_id = "test_endocrine_#{System.unique_integer([:positive])}"
    
    # We attempt connection. 
    # To avoid 60s timeout, we can set a shorter timeout if Tortoise allows, 
    # but for now we just want to ensure the API is called correctly.
    # In a real environment, this would connect to NATS/MQTT.
    
    # If we are in a pure test env, we might want to mock Tortoise.
    # For now, let's just assert the call returns a PID or an error.
    Process.flag(:trap_exit, true)
    res = Endocrine.start_connection(client_id, "nats://127.0.0.1:4222")
    assert match?({:ok, _}, res) or match?({:error, _}, res)

    assert_receive {:endocrine_event, event, %{plane: :global_control, client_id: ^client_id}}, 5_000
    assert event in [
             [:karyon, :nervous_system, :endocrine, :connect_ok],
             [:karyon, :nervous_system, :endocrine, :connect_failed]
           ]
    
    case res do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end

  test "publish failure emits endocrine telemetry on invalid pid" do
    assert {:error, _reason} = Endocrine.publish_gradient(self(), "metabolic.spike", "payload")

    assert_receive {:endocrine_event, [:karyon, :nervous_system, :endocrine, :publish_failed], %{plane: :global_control, topic: "metabolic.spike", bytes: 7}}, 1_000
  end

  test "subscribe failure emits endocrine telemetry on invalid pid" do
    assert {:error, _reason} = Endocrine.subscribe(self(), "metabolic.spike")

    assert_receive {:endocrine_event, [:karyon, :nervous_system, :endocrine, :subscribe_failed], %{plane: :global_control, topic: "metabolic.spike"}}, 1_000
  end
end
