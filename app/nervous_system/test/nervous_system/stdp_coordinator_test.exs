defmodule Sensory.STDPCoordinatorTest do
  use ExUnit.Case, async: false

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, %{pressure: :low, node_locks: Keyword.get(opts, :node_locks, %{})}, name: Core.MetabolicDaemon)
    end

    def init(state), do: {:ok, state}
    def handle_call(:get_pressure, _from, state), do: {:reply, state.pressure, state}
    def handle_call({:get_node_lock_status, node_ids}, _from, state) do
      statuses = Map.new(node_ids, fn node_id -> {node_id, Map.get(state.node_locks, node_id, :unlocked)} end)
      {:reply, statuses, state}
    end
    def handle_call({:set_node_locks, locks}, _from, state), do: {:reply, :ok, %{state | node_locks: locks}}
  end

  setup do
    Application.ensure_all_started(:nervous_system)
    case Process.whereis(Core.MetabolicDaemon) do
      nil -> :ok
      pid ->
        Process.unlink(pid)
        GenServer.stop(pid)
    end

    {:ok, daemon} = FakeMetabolicDaemon.start_link()
    on_exit(fn ->
      if Process.alive?(daemon), do: GenServer.stop(daemon)
    end)

    :ok
  end

  test "starts under NervousSystem.Application supervision" do
    children = Supervisor.which_children(NervousSystem.Supervisor)
    assert Enum.any?(children, fn {id, pid, _type, _modules} -> id == Sensory.STDPCoordinator and is_pid(pid) end)
  end

  test "emits targeted edge updates only for the matching trace inside the eligibility window" do
    {:ok, pid} = Sensory.STDPCoordinator.start_link(name: :stdp_test_coordinator, window_ms: 4_000)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    GenServer.cast(pid, {:register_trace, %{motor_action_id: "motor-1", sensory_id: "sensory-1", source_node: "sensory-1", predicted_target: "motor-1", stem_cell_pid: self()}})
    GenServer.cast(pid, {:register_trace, %{motor_action_id: "motor-2", sensory_id: "sensory-2", source_node: "sensory-2", predicted_target: "motor-2", stem_cell_pid: self()}})

    prediction_error = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      source: "operator_induced",
      severity: 0.9,
      source_node: "sensory-1",
      predicted_target: "motor-1",
      corrected_target: "motor-1-corrected"
    }

    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(prediction_error)
    send(pid, {:msg, "operator.nociception", IO.iodata_to_binary(payload)})

    assert_receive {:stdp_targeted_edge_update, correction}, 1_000
    assert correction.source_node == "sensory-1"
    assert correction.predicted_target == "motor-1"
    assert correction.corrected_target == "motor-1-corrected"
    assert correction.negative_spike.target_node == "motor-1"
    assert correction.positive_spike.target_node == "motor-1-corrected"
    refute_receive {:stdp_targeted_edge_update, %{source_node: "sensory-2"}}, 300
  end

  test "drops expired traces outside the eligibility window" do
    {:ok, pid} = Sensory.STDPCoordinator.start_link(name: :stdp_short_window, window_ms: 3_000)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    stale_at = System.monotonic_time(:millisecond) - 3_100
    GenServer.cast(pid, {:register_trace, %{motor_action_id: "motor-stale", sensory_id: "sensory-stale", source_node: "sensory-stale", predicted_target: "motor-stale", stem_cell_pid: self(), recorded_at_ms: stale_at}})

    prediction_error = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      source: "operator_induced",
      severity: 1.0,
      source_node: "sensory-stale",
      predicted_target: "motor-stale",
      corrected_target: "motor-corrected"
    }

    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(prediction_error)
    send(pid, {:msg, "operator.nociception", IO.iodata_to_binary(payload)})

    refute_receive {:stdp_targeted_edge_update, _correction}, 300
    assert %{trace_count: 0, deferred_count: 0} = Sensory.STDPCoordinator.runtime_state(pid)
  end

  test "defers targeted edge updates while target nodes are locked by MetabolicDaemon" do
    {:ok, pid} = Sensory.STDPCoordinator.start_link(name: :stdp_locked_coordinator, window_ms: 4_000, retry_delay_ms: 20)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    GenServer.cast(pid, {:register_trace, %{motor_action_id: "motor-locked", sensory_id: "sensory-locked", source_node: "sensory-locked", predicted_target: "motor-locked", stem_cell_pid: self()}})
    GenServer.call(Core.MetabolicDaemon, {:set_node_locks, %{"motor-locked" => :locked}})

    prediction_error = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      source: "operator_induced",
      severity: 0.7,
      source_node: "sensory-locked",
      predicted_target: "motor-locked",
      corrected_target: "motor-corrected"
    }

    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(prediction_error)
    send(pid, {:msg, "operator.nociception", IO.iodata_to_binary(payload)})

    refute_receive {:stdp_targeted_edge_update, _correction}, 50
    assert %{deferred_count: 1} = Sensory.STDPCoordinator.runtime_state(pid)

    GenServer.call(Core.MetabolicDaemon, {:set_node_locks, %{"motor-locked" => :unlocked, "motor-corrected" => :unlocked, "sensory-locked" => :unlocked}})
    assert_receive {:stdp_targeted_edge_update, correction}, 500
    assert correction.predicted_target == "motor-locked"
    assert correction.corrected_target == "motor-corrected"
  end

  test "drops prediction errors with missing targeting fields" do
    {:ok, pid} = Sensory.STDPCoordinator.start_link(name: :stdp_invalid_targeting, window_ms: 4_000)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    GenServer.cast(pid, {:register_trace, %{motor_action_id: "motor-1", sensory_id: "sensory-1", source_node: "sensory-1", predicted_target: "motor-1", stem_cell_pid: self()}})

    prediction_error = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      source: "operator_induced",
      severity: 0.9,
      source_node: "sensory-1",
      predicted_target: "",
      corrected_target: "motor-1-corrected"
    }

    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(prediction_error)
    send(pid, {:msg, "operator.nociception", IO.iodata_to_binary(payload)})

    refute_receive {:stdp_targeted_edge_update, _correction}, 300
    assert %{trace_count: 1, deferred_count: 0} = Sensory.STDPCoordinator.runtime_state(pid)
  end
end
