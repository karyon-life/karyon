defmodule Core.PlatformIntegrationTest do
  use ExUnit.Case, async: false # Integration tests usually aren't async due to global shared resources

  setup_all do
    # This would ideally boot the whole umbrella, but we use the harness
    {:ok, organism} = Core.TestHarness.genesis_boot()
    {:ok, organism: organism}
  end

  test "organism responds to sensory perception and nociception", %{organism: organism} do
    code = "fn main() { println!(\"Hello\"); }"
    :ok = Core.TestHarness.simulate_perception(organism, "javascript", code)
    
    # Verify cells are still active (regeneration or survival)
    for cell_pid <- organism.cells do
      assert Process.alive?(cell_pid)
      status = GenServer.call(cell_pid, :get_status)
      assert status == :active
    end
  end
end
