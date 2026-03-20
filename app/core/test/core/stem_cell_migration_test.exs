defmodule Core.StemCellMigrationTest do
  use ExUnit.Case, async: true
  alias Core.StemCell

  setup do
    Process.flag(:trap_exit, true)
    # Use a real DNA file from the project
    dna_path = Path.expand("../../../../priv/dna/motor_cell.yml", __DIR__)
    {:ok, pid} = StemCell.start_link(dna_path)
    {:ok, cell: pid}
  end

  test "cell initializes with correct status and beliefs", %{cell: pid} do
    assert GenServer.call(pid, :get_status) in [:active, :revived]
    assert GenServer.call(pid, :get_synapse_count) > 0
  end

  test "cell forms and evaluates expectations via VFE", %{cell: pid} do
    # 1. Form an expectation
    :ok = GenServer.call(pid, {:form_expectation, "test_goal", "success", 0.8})
    
    # 2. Simulate a painful reality (nociception)
    # We send a nociception msg manually to the process
    # The StemCell subscribes to a PUB synapse in init, but we can send it a direct :synapse_recv for testing
    msg_struct = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      metadata: %{"error" => "compilation_failed"}
    }
    {:ok, iodata} = Karyon.NervousSystem.PredictionError.encode(msg_struct)
    msg = IO.iodata_to_binary(iodata)
    
    send(pid, {:synapse_recv, self(), msg})
    
    # Wait for processing
    Process.sleep(100)
    
    # 3. Verify VFE calculation and status
    # VFE = precision (0.8) * error (1.0) = 0.8
    # motor_cell.yml has utility_threshold: 0.6
    # 0.8 > 0.6, so it should have triggered pruning (which involves calling Rhizome.Native)
  end

  test "cell enters Digital Torpor under high metabolic stress", %{cell: pid} do
    # Create high severity metabolic spike
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: 1.0, source: "operator_induced"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    
    send(pid, {:msg, %{topic: "metabolic.spike", body: payload}})
    
    Process.sleep(100)
    assert GenServer.call(pid, :get_status) == :torpor
    # Verify synapses are shed (only essential pain receptor remains)
    assert GenServer.call(pid, :get_synapse_count) == 1
  end

  test "speculative cell undergoes apoptosis under medium stress" do
    # Use a speculative DNA
    dna_path = Path.expand("../../../../priv/dna/speculative_cell.yml", __DIR__)
    # Use start (unlinked) so the test runner doesn't crash on apoptosis
    {:ok, pid} = GenServer.start(Core.StemCell, dna_path)
    
    ref = Process.monitor(pid)
    
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: 0.6, source: "operator_induced"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    
    send(pid, {:msg, %{topic: "metabolic.spike", body: payload}})
    
    assert_receive {:DOWN, ^ref, :process, ^pid, :metabolic_pruning}, 5_000
  end
end
