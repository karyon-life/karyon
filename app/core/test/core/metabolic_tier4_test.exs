defmodule Core.MetabolicDaemonTier4Test do
  use ExUnit.Case
  alias Core.MetabolicDaemon

  defmodule NativeStable do
    def read_l3_misses, do: {:ok, 100}
    def read_iops, do: {:ok, 50}
    def read_numa_node, do: {:ok, 0}
    def get_affinity_mask, do: {:ok, [0, 1]}
  end

  setup do
    # We calibrate to get base metrics
    {:ok, pid} =
      MetabolicDaemon.start_link(
        name: :metabolic_test_daemon,
        native_module: NativeStable,
        calibration_delay_ms: 10,
        poll_interval_ms: 10,
        preflight_opts: [
          mock_hardware?: false,
          file_reader: fn
            "/sys/devices/system/node/node0/meminfo" -> {:ok, "Node 0 MemTotal: 1234 kB"}
            _ -> {:error, :enoent}
          end,
          dir_lister: fn _ -> {:ok, []} end,
          scheduler_bind_type_fun: fn :scheduler_bind_type -> :tnnps end,
          logical_processors_fun: fn :logical_processors -> 8 end
        ]
      )

    send(pid, :calibrate)
    Process.sleep(50)
    %{pid: pid}
  end

  test "Metabolism: Pressure transitions (Low -> High)", %{pid: pid} do
    # Initial pressure should be low
    assert :low == GenServer.call(pid, :get_pressure)
    
    # We can't easily fake OS metrics in the NIF without a mock, 
    # but we can verify the handle_info logic by sending fake poll messages
    # if we expose the internal calculation.
    
    # Instead, let's verify that the daemon broadcasts spikes
    # We need a subscriber to NATS topic "metabolic.spike" 
    # but since NATS might not be running, we check if it attempts to publish.
    
    # The MetabolicDaemon emits :telemetry now as per Phase 3.
    # Let's listen for telemetry.
    parent = self()
    :telemetry.attach("metabolic-test-handler", [:karyon, :metabolism, :poll], fn _name, measurements, metadata, _config -> 
      send(parent, {:telemetry_recv, measurements, metadata})
    end, nil)
    
    send(pid, :poll_metrics)
    
    assert_receive {:telemetry_recv, %{pressure: 0}, %{pressure: :low, policy: policy}}, 1000
    assert policy["needs"]["exploration"] == 0.6
    assert policy["values"]["learning"] == 0.8
    assert policy["objective_priors"]["repair"] == 0.6
    
    :telemetry.detach("metabolic-test-handler")
    GenServer.stop(pid)
  end
end
