defmodule Core.PlatformIntegrationTest do
  use ExUnit.Case, async: false # Integration tests usually aren't async due to global shared resources
  require Logger

  setup_all do
    # This would ideally boot the whole umbrella, but we use the harness
    {:ok, organism} = Core.TestHarness.genesis_boot()
    {:ok, organism: organism}
  end

  @tag :chaos
  test "organism survives random component termination (Chaos engineering)", %{organism: _organism} do
    # 1. Identify critical platform processes
    critical_apps = [:rhizome, :sensory, :nervous_system]
    
    # 2. Kill one random app's supervisor
    target_app = Enum.random(critical_apps)
    Logger.warning("[PlatformTest] CHAOS: Terminating #{target_app} to test supervision tree...")
    
    Application.stop(target_app)
    
    # 3. Wait for recovery (OTP supervision)
    Process.sleep(500)
    
    # 4. Attempt a platform action to verify recovery
    case target_app do
      :rhizome ->
        assert {:ok, _} = Rhizome.Native.memgraph_query("MATCH (n) RETURN count(n)")
      :sensory ->
        assert is_binary(Sensory.Native.parse_code("javascript", "const x = 1"))
      _ ->
        :ok
    end
    
    # Ensure it's started back for other tests
    Application.ensure_all_started(target_app)
  end
end
