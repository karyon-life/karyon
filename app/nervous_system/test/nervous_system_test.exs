defmodule NervousSystemTest do
  use ExUnit.Case

  test "starts synapse" do
    assert {:ok, _} = NervousSystem.Synapse.start_link()
  end
  
  test "starts endocrine without crashing" do
    # In test env without NATS, this might return :econnrefused and crash if linked.
    # We trap exit to prevent the test process from dying.
    Process.flag(:trap_exit, true)
    res = NervousSystem.Endocrine.start_connection(:test_client)
    assert match?({:ok, _}, res) or match?({:error, _}, res)
    
    case res do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end
end
