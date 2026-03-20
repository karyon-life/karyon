defmodule Core.SimulationDaemonTest do
  use ExUnit.Case, async: true

  alias Core.SimulationDaemon

  defmodule MemoryStub do
    def query_grammar_supernodes(_opts) do
      {:ok,
       [
         %{
           "id" => "grammar_supernode:rule-1",
           "kind" => "structural_grammar_rule",
           "confidence" => 0.7,
           "pooled_sequence_ids" => ["sequence-a", "sequence-b", "sequence-c"]
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
    def query_grammar_supernodes(_opts), do: {:ok, []}
    def submit_simulation_daemon_event(_event), do: {:ok, %{id: "unused"}}
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

  test "run_once/1 dreams over grammar super-nodes via internal monte carlo simulation" do
    assert {:ok, result} =
             SimulationDaemon.run_once(
               policy: Core.MetabolismPolicy.build_policy(:low),
               memory_module: MemoryStub
             )

    assert result.source_outcome["id"] == "grammar_supernode:rule-1"
    assert result.intent.action == "execute_plan"
    assert result.plan.transition_delta[:simulation]["permutation_mode"] == "reorder_step_sequence"
    assert result.intent.transition_delta["metabolism_admission"]["status"] == "admitted"
    assert result.result.status == "simulated"
    assert result.result.predicted_free_energy > 0.0
    assert result.result.grammar_supernode_ids == ["grammar_supernode:rule-1"]
    assert result.result.sequence_lineage == ["sequence-a", "sequence-b", "sequence-c"]

    assert_receive {:simulation_event_persisted, event}
    assert event["source_outcome_id"] == "grammar_supernode:rule-1"
    assert event["permutation_mode"] == "reorder_step_sequence"
    assert event["dream_mode"] == "grammar_monte_carlo"
    assert event["external_motor_output_used"] == false
    assert event["outcome_status"] == "simulated"
    refute Map.has_key?(event, "vm_id")
  end

  test "run_once/1 refuses dream-state work when the organism is not idle" do
    assert {:error, :organism_not_idle} =
             SimulationDaemon.run_once(
               policy: Core.MetabolismPolicy.build_policy(:high),
               memory_module: MemoryStub
             )
  end

  test "run_once/1 returns a bounded error when no grammar super-nodes exist" do
    assert {:error, :no_simulation_source_outcomes} =
             SimulationDaemon.run_once(
               policy: Core.MetabolismPolicy.build_policy(:low),
               memory_module: EmptyMemoryStub
             )
  end
end
