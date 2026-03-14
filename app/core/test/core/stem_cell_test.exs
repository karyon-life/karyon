defmodule Core.StemCellTest do
  use ExUnit.Case, async: true
  require Logger

  setup do
    # Ensure pg is started
    :pg.start_link()
    :ok
  end

  test "stem cell boots and joins pg group" do
    # DNA path is relative to the app root
    dna_path = Path.expand("../../config/genetics/base_stem_cell.yml", __DIR__)
    {:ok, pid} = Core.StemCell.start_link(dna_path)
    
    # Check if joined pg
    assert self() not in :pg.get_members(:stem_cell)
    # Allow pg membership to propagate
    Process.sleep(500)
    assert pid in :pg.get_members(:stem_cell)
    
    status = GenServer.call(pid, :get_status)
    assert status == :active
  end

  test "stem cell forms and prunes expectations on nociception with VFE" do
    dna_path = Path.expand("../../config/genetics/base_stem_cell.yml", __DIR__)
    {:ok, pid} = Core.StemCell.start_link(dna_path)
    
    # New API: {:form_expectation, id, goal, precision}
    :ok = GenServer.call(pid, {:form_expectation, :t1, "Success", 0.8})
    :ok = GenServer.call(pid, {:form_expectation, :t2, "Growth", 0.4})
    
    # Simulate receiving nociception signal via synapse message
    # Expect VFE = 0.8 * 1.0 + 0.4 * 1.0 = 1.2
    send(pid, {:synapse_recv, self(), Jason.encode!(%{type: "nociception", metadata: %{error: "timeout"}})})
    
    # Wait for processing
    Process.sleep(100)
    
    # Check if beliefs were updated with last VFE
    # 1.2 because [t1: 0.5, t2: 0.7] sum
    state = :sys.get_state(pid)
    assert_in_delta state.beliefs.last_vfe, 1.2, 0.00001
    assert state.expectations == %{}
  end
end
