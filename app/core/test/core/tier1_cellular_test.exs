defmodule Core.StemCellTier1Test do
  use ExUnit.Case
  alias Core.StemCell

  @dna_path "priv/dna/architect_planner.yml"

  setup do
    {:ok, pid} = StemCell.start(@dna_path)
    %{pid: pid}
  end

  test "differentiation: only allowed actions are executed", %{pid: pid} do
    # 'form_expectation' is allowed in architect_planner.yml
    assert :ok == GenServer.call(pid, {:form_expectation, "test_goal", %{target: 1}, 0.9})
    
    # 'unknown_action' is NOT allowed
    assert {:error, :unauthorized} == GenServer.call(pid, {:execute, "unknown_action", %{}})
  end

  test "nociception: VFE increases on pain signals", %{pid: pid} do
    # Form an expectation with high precision
    GenServer.call(pid, {:form_expectation, "goal_1", %{x: 1}, 1.0})
    
    # Send a nociception signal (prediction error)
    # We use the internal handle_info for synapse_recv
    # The payload is a PredictionError proto
    
    msg = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      metadata: %{"error" => "collision"}
    }
    {:ok, binary} = Karyon.NervousSystem.PredictionError.encode(msg)
    
    send(pid, {:synapse_recv, self(), binary})
    
    # Wait for processing
    Process.sleep(100)
    
    # Check beliefs - last_vfe should be set to 1.0 (precision * 1.0 error)
    # Since we don't have a direct getter for beliefs in StemCell, let's add a helper or use :sys.get_state
    state = :sys.get_state(pid)
    assert state.beliefs.last_vfe == 1.0
  end

  test "apoptosis: high VFE triggers structural pruning", %{pid: pid} do
    # Form an expectation with high precision
    GenServer.call(pid, {:form_expectation, "goal_critical", %{x: 100}, 2.0})
    
    # Utility threshold is 0.2 in architect_planner.yml
    # A pain signal will result in VFE = 2.0 * 1.0 = 2.0, which is > 0.2
    
    msg = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      metadata: %{"error" => "catastrophic"}
    }
    {:ok, binary} = Karyon.NervousSystem.PredictionError.encode(msg)
    
    # Monitoring pruning is hard without a mock for Rhizome.Native
    # but we can verify the state after pruning
    send(pid, {:synapse_recv, self(), binary})
    Process.sleep(100)
    
    state = :sys.get_state(pid)
    assert state.expectations == %{} # Expectations should be cleared after pruning
  end
end

defmodule Core.YamlParserTest do
  use ExUnit.Case
  alias Core.YamlParser

  test "apoptotic safety: invalid YAML crashes the process" do
    bad_yaml_path = "/tmp/invalid_dna.yml"
    File.write!(bad_yaml_path, "invalid: : : :")
    
    assert_raise YamlElixir.ParsingError, fn ->
      YamlParser.transcribe!(bad_yaml_path)
    end
    
    File.rm(bad_yaml_path)
  end
end
