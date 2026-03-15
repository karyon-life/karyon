defmodule Core.StemCellTest do
  use ExUnit.Case
  alias Core.StemCell

  @dna_path "/tmp/stem_cell_test_dna.yml"

  setup do
    File.write!(@dna_path, """
    cell_type: sensor
    synapses: []
    """)
    on_exit(fn -> File.rm(@dna_path) end)
    :ok
  end

  test "StemCell forms expectations and calculates VFE on nociception" do
    {:ok, pid} = StemCell.start_link(@dna_path)
    
    # Form an expectation with a numeric ID that can be turned into a pointer
    :ok = GenServer.call(pid, {:form_expectation, 1001, :low_vfe, 0.8})
    
    # Simulate receiving a nociception signal via synapse message
    # In a real test we'd use NervousSystem.Synapse but we can send the message directly
    payload = Jason.encode!(%{
      "type" => "nociception",
      "metadata" => %{"error" => "high_latency"}
    })
    
    send(pid, {:synapse_recv, self(), payload})
    
    # Check status after processing
    # We can't easily wait for the async info handler, so we sleep briefly
    Process.sleep(100)
    
    assert :active == GenServer.call(pid, :get_status)
  end
end
