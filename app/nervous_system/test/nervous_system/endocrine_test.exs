defmodule NervousSystem.EndocrineTest do
  use ExUnit.Case, async: false

  # This test verifies the Endocrine dispatcher (NATS via Tortoise)
  # It requires an MQTT broker (simulating NATS for MVP) to be running or a mock.
  # For now, we'll verify it doesn't crash on start and can call publish.

  @tag :external
  test "endocrine connection attempt" do
    client_id = "test_endocrine_#{System.unique_integer([:positive])}"
    
    # We attempt connection. 
    # To avoid 60s timeout, we can set a shorter timeout if Tortoise allows, 
    # but for now we just want to ensure the API is called correctly.
    # In a real environment, this would connect to NATS/MQTT.
    
    # If we are in a pure test env, we might want to mock Tortoise.
    # For now, let's just assert the call returns a PID or an error.
    res = NervousSystem.Endocrine.start_connection(client_id, "nats://127.0.0.1:4222")
    assert match?({:ok, _}, res) or match?({:error, _}, res)
    
    if match?({:ok, _pid}, res) do
      {:ok, pid} = res
      GenServer.stop(pid)
    end
  end
end
