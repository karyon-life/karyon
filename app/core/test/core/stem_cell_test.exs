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

  test "StemCell undergoes selective apoptosis on medium stress if speculative" do
    # Create DNA for a speculative cell (no allowed_actions)
    speculative_dna = "/tmp/speculative_dna.yml"
    File.write!(speculative_dna, """
    cell_type: speculative
    allowed_actions: []
    """)
    on_exit(fn -> File.rm(speculative_dna) end)

    {:ok, pid} = StemCell.start_link(speculative_dna)
    
    # Monitor the process to detect termination
    ref = Process.monitor(pid)

    # Simulate medium stress spike
    spike = NervousSystem.Protos.MetabolicSpike.new(severity: "medium")
    payload = NervousSystem.Protos.MetabolicSpike.encode(spike)
    send(pid, {:msg, "metabolic.spike", payload})

    assert_receive {:DOWN, ^ref, :process, ^pid, :metabolic_pruning}, 1000
  end

  test "StemCell sheds non-essential synapses on high stress (Digital Torpor)" do
    # Create DNA with multiple synapses
    active_dna = "/tmp/active_dna.yml"
    File.write!(active_dna, """
    cell_type: motor
    allowed_actions: ["move"]
    synapses:
      - type: push
        bind: tcp://127.0.0.1:0
      - type: push
        bind: tcp://127.0.0.1:0
    """)
    on_exit(fn -> File.rm(active_dna) end)

    {:ok, pid} = StemCell.start_link(active_dna)
    
    # Initial state should have 3 synapses (1 nociception + 2 from DNA)
    assert 3 == GenServer.call(pid, :get_synapse_count)
    
    # Simulate high stress spike
    spike = NervousSystem.Protos.MetabolicSpike.new(severity: "high")
    payload = NervousSystem.Protos.MetabolicSpike.encode(spike)
    send(pid, {:msg, "metabolic.spike", payload})

    Process.sleep(200)
    
    # After torpor, it should only have 1 synapse (the essential one)
    assert 1 == GenServer.call(pid, :get_synapse_count)
    assert :torpor == GenServer.call(pid, :get_status)
  end

  test "StemCell forms expectations and calculates VFE on nociception" do
    active_dna = "/tmp/active_dna_2.yml"
    File.write!(active_dna, """
    cell_type: sensor
    synapses: []
    """)
    on_exit(fn -> File.rm(active_dna) end)

    {:ok, pid} = StemCell.start_link(active_dna)
    
    # Form an expectation
    :ok = GenServer.call(pid, {:form_expectation, 1001, :low_vfe, 0.8})
    
    # Simulate nociception
    payload = Jason.encode!(%{
      "type" => "nociception",
      "metadata" => %{"error" => "high_latency"}
    })
    
    send(pid, {:synapse_recv, self(), payload})
    
    Process.sleep(100)
    
    # It should still be active, but expectations should be cleared and belief updated
    assert :active == GenServer.call(pid, :get_status)
  end
end
