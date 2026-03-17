defmodule Dashboard.TelemetryBridgeTest do
  use ExUnit.Case, async: true

  test "handle_event/4 broadcasts the real metabolic payload" do
    Phoenix.PubSub.subscribe(Dashboard.PubSub, "metabolic_flux")

    Dashboard.TelemetryBridge.handle_event(
      [:karyon, :metabolism, :poll],
      %{pressure: 2},
      %{
        pressure: :high,
        l3_misses: 12_345,
        run_queue: 9,
        iops: 4_321,
        atp: 0.4,
        preflight_status: {:degraded, "numa drift"}
      },
      nil
    )

    assert_receive {:metabolic_update,
                    %{
                      pressure: :high,
                      l3_misses: 12_345,
                      run_queue: 9,
                      iops: 4_321,
                      atp: 0.4,
                      preflight_status: {:degraded, "numa drift"}
                    }}
  end
end
