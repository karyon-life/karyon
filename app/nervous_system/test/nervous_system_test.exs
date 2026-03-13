defmodule NervousSystemTest do
  use ExUnit.Case

  test "starts synapse" do
    assert {:ok, _} = NervousSystem.Synapse.start_link()
  end
  
  test "starts endocrine without crashing" do
    # Tortoise connects to NATS in the background and will crash the supervisor if NATS is down,
    # but the start_link itself should return an :ok tuple immediately if the GenServer boots.
    assert {:ok, _} = NervousSystem.Endocrine.start_connection(:test_client)
  end
end
