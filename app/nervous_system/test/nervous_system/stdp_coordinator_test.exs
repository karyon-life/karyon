defmodule Sensory.STDPCoordinatorTest do
  use ExUnit.Case, async: false

  setup do
    Application.ensure_all_started(:nervous_system)
    :ok
  end

  test "starts under NervousSystem.Application supervision" do
    children = Supervisor.which_children(NervousSystem.Supervisor)
    assert Enum.any?(children, fn {id, pid, _type, _modules} -> id == Sensory.STDPCoordinator and is_pid(pid) end)
  end

  test "emits stdp prediction errors for active traces inside the eligibility window" do
    {:ok, pid} = Sensory.STDPCoordinator.start_link(name: :stdp_test_coordinator, window_ms: 4_000)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    GenServer.cast(pid, {:register_trace, %{motor_action_id: "motor-1", sensory_id: "sensory-1", stem_cell_pid: self()}})

    prediction_error = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      source: "operator_induced",
      severity: 0.9
    }

    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(prediction_error)
    send(pid, {:msg, "operator.nociception", IO.iodata_to_binary(payload)})

    assert_receive {:stdp_prediction_error, "sensory-1", severity}, 1_000
    assert_in_delta severity, 0.9, 0.0001
  end

  test "drops expired traces outside the eligibility window" do
    {:ok, pid} = Sensory.STDPCoordinator.start_link(name: :stdp_short_window, window_ms: 3_000)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    stale_at = System.monotonic_time(:millisecond) - 3_100
    GenServer.cast(pid, {:register_trace, %{motor_action_id: "motor-stale", sensory_id: "sensory-stale", stem_cell_pid: self(), recorded_at_ms: stale_at}})

    prediction_error = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      source: "operator_induced",
      severity: 1.0
    }

    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(prediction_error)
    send(pid, {:msg, "operator.nociception", IO.iodata_to_binary(payload)})

    refute_receive {:stdp_prediction_error, "sensory-stale", _severity}, 300
    assert %{trace_count: 0} = Sensory.STDPCoordinator.runtime_state(pid)
  end
end
