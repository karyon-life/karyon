defmodule Core.SimulationDaemonTest do
  use ExUnit.Case, async: true

  alias Core.SimulationDaemon

  defmodule MemoryStub do
    def query_recent_execution_outcomes(_opts) do
      {:ok,
       [
         %{
           "xt/id" => "execution_outcome:planner:patch_codebase:1",
           "cell_id" => "planner",
           "action" => "execute_plan",
           "status" => "success",
           "vm_id" => "vm-history-1",
           "plan_attractor_id" => "repair-attractor",
           "plan_step_ids" => ["step-1", "step-2"],
           "result" => %{"telemetry" => %{"summary" => %{"mutation_count" => 2}}}
         }
       ]}
    end

    def submit_simulation_daemon_event(event) do
      if pid = Process.whereis(:simulation_daemon_observer) do
        send(pid, {:simulation_event_persisted, event})
      end

      {:ok, %{id: "simulation_daemon:execution_outcome:planner:patch_codebase:1"}}
    end
  end

  defmodule EmptyMemoryStub do
    def query_recent_execution_outcomes(_opts), do: {:ok, []}
    def submit_simulation_daemon_event(_event), do: {:ok, %{id: "unused"}}
  end

  defmodule ExecutorStub do
    def execute_plan(intent) do
      if pid = Process.whereis(:simulation_daemon_observer) do
        send(pid, {:dream_execute_plan, intent})
      end

      {:ok,
       %{status: :exited, exit_code: 0, vm_id: "dream-vm", telemetry: %{"summary" => %{"mutation_count" => 1}}}}
    end
  end

  setup do
    Process.register(self(), :simulation_daemon_observer)

    on_exit(fn ->
      if Process.whereis(:simulation_daemon_observer) == self() do
        Process.unregister(:simulation_daemon_observer)
      end
    end)

    :ok
  end

  test "run_once/1 dreams over recent successful execution outcomes through sandbox execute_plan" do
    assert {:ok, result} =
             SimulationDaemon.run_once(
               policy: Core.MetabolismPolicy.build_policy(:low),
               memory_module: MemoryStub,
               executor_module: ExecutorStub
             )

    assert result.source_outcome["xt/id"] == "execution_outcome:planner:patch_codebase:1"
    assert result.intent.action == "execute_plan"
    assert result.plan.transition_delta[:simulation]["permutation_mode"] == "reorder_step_sequence"
    assert result.intent.transition_delta["metabolism_admission"]["status"] == "admitted"

    assert_receive {:dream_execute_plan, intent}
    assert intent["action"] == "execute_plan"
    assert hd(intent["params"]["steps"])["action"] == "simulate_permutation"

    assert_receive {:simulation_event_persisted, event}
    assert event["source_outcome_id"] == "execution_outcome:planner:patch_codebase:1"
    assert event["permutation_mode"] == "reorder_step_sequence"
    assert event["outcome_status"] == "exited"
    assert event["vm_id"] == "dream-vm"
  end

  test "run_once/1 refuses dream-state work when the organism is not idle" do
    assert {:error, :organism_not_idle} =
             SimulationDaemon.run_once(
               policy: Core.MetabolismPolicy.build_policy(:high),
               memory_module: MemoryStub,
               executor_module: ExecutorStub
             )

    refute_received {:dream_execute_plan, _intent}
  end

  test "run_once/1 returns a bounded error when no historical execution outcomes exist" do
    assert {:error, :no_simulation_source_outcomes} =
             SimulationDaemon.run_once(
               policy: Core.MetabolismPolicy.build_policy(:low),
               memory_module: EmptyMemoryStub,
               executor_module: ExecutorStub
             )
  end
end
