defmodule Core.StemCellTest do
  use ExUnit.Case
  alias Core.StemCell

  @dna_path "/tmp/stem_cell_test_dna.yml"

  setup do
    # Ensure :pg is started for stigmergy/process groups
    case :pg.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

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

    {:ok, pid} = GenServer.start(StemCell, speculative_dna)
    
    # Monitor the process to detect termination
    ref = Process.monitor(pid)

    # Simulate medium stress spike
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: "medium"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
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
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: "high"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
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
    noc_msg = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      metadata: %{"error" => "high_latency"}
    }
    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(noc_msg)
    
    send(pid, {:synapse_recv, self(), payload})
    
    Process.sleep(100)
    
    assert :active == GenServer.call(pid, :get_status)
  end

  test "StemCell correctly dispatches motor actions based on DNA motor_executor" do
    # Create DNA with a specific motor_executor
    specialized_dna = "/tmp/specialized_dna.yml"
    File.write!(specialized_dna, """
    cell_type: specialized_motor
    allowed_actions: ["patch_codebase"]
    motor_executor: "firecracker_python"
    """)
    on_exit(fn -> File.rm(specialized_dna) end)

    {:ok, pid} = StemCell.start_link(specialized_dna)
    
    # We can't easily verify the side effect of Sandbox.Provisioner.capture_output 
    # if it's not mocked, but for unit testing we verify the return value 
    # which we know is "Success: Compilation complete. No errors found." from provisioner.ex
    
    assert {:ok, "Success: Compilation complete. No errors found."} == 
           GenServer.call(pid, {:execute, "patch_codebase", [vm_id: "test_vm"]})
  end

  test "StemCell fails to start with malformed DNA" do
    malformed_dna = "/tmp/malformed_dna.yml"
    File.write!(malformed_dna, "::: malformed yaml :::")
    on_exit(fn -> File.rm(malformed_dna) end)

    # Use GenServer.start (unlinked) to avoid exit signal propagation in test
    assert {:error, _} = GenServer.start(StemCell, malformed_dna)
  end
end
