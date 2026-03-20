defmodule Core.StemCellTest do
  use ExUnit.Case
  alias Core.StemCell

  defmodule MemoryStub do
    def load_cell_state(_lineage_id), do: {:error, :not_found}
    def checkpoint_cell_state(_snapshot), do: {:ok, %{id: "checkpoint"}}
    def submit_prediction_error(prediction_error) do
      if pid = Process.whereis(:stem_cell_test_observer) do
        send(pid, {:prediction_error_persisted, prediction_error})
      end

      {:ok, %{id: prediction_error["id"] || "prediction_error"}}
    end

    def submit_execution_outcome(outcome) do
      if pid = Process.whereis(:stem_cell_test_observer) do
        send(pid, {:execution_outcome_persisted, outcome})
      end

      {:ok, %{id: outcome["cell_id"]}}
    end

    def submit_execution_telemetry(telemetry) do
      if pid = Process.whereis(:stem_cell_test_observer) do
        send(pid, {:execution_telemetry_persisted, telemetry})
      end

      {:ok, %{id: telemetry["telemetry_id"]}}
    end

    def submit_sovereignty_event(event) do
      if pid = Process.whereis(:stem_cell_test_observer) do
        send(pid, {:sovereignty_event_persisted, event})
      end

      {:ok, %{id: event["id"]}}
    end

    def prune_stdp_pathway(event) do
      if pid = Process.whereis(:stem_cell_test_observer) do
        send(pid, {:stdp_pathway_pruned, event})
      end

      mode = if event["severity"] < 0.5, do: :depressed, else: :deleted
      {:ok, %{plasticity_mode: mode, sensory_id: event["sensory_id"], motor_id: event["motor_id"]}}
    end
  end

  defmodule RhizomeStub do
    def prune_pathway(pathway) do
      if pid = Process.whereis(:stem_cell_test_observer) do
        send(pid, {:pathway_pruned, pathway})
      end

      {:ok, %{message: "pruned", from_id: pathway[:from_id], to_id: pathway[:to_id]}}
    end

    def reinforce_pathway(pathway) do
      if pid = Process.whereis(:stem_cell_test_observer) do
        send(pid, {:pathway_reinforced, pathway})
      end

      {:ok, %{message: "reinforced", from_id: pathway[:from_id], to_id: pathway[:to_id]}}
    end
  end

  @dna_path "/tmp/stem_cell_test_dna.yml"

  setup do
    # Ensure :pg is started for stigmergy/process groups
    case :pg.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    original_module = Application.get_env(:core, :memory_module)
    original_rhizome_module = Application.get_env(:core, :rhizome_module)
    Application.put_env(:core, :memory_module, MemoryStub)
    Application.put_env(:core, :rhizome_module, RhizomeStub)

    if Process.whereis(:stem_cell_test_observer), do: Process.unregister(:stem_cell_test_observer)

    File.write!(@dna_path, """
    cell_type: sensor
    synapses: []
    """)

    on_exit(fn ->
      File.rm(@dna_path)

      if Process.whereis(:stem_cell_test_observer), do: Process.unregister(:stem_cell_test_observer)

      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end

      if original_rhizome_module do
        Application.put_env(:core, :rhizome_module, original_rhizome_module)
      else
        Application.delete_env(:core, :rhizome_module)
      end
    end)

    :ok
  end

  test "StemCell undergoes selective apoptosis on medium stress if speculative" do
    # Create DNA for a speculative cell (no allowed_actions)
    speculative_dna = "/tmp/speculative_dna.yml"
    File.write!(speculative_dna, """
    cell_type: speculative
    allowed_actions: []
    """)
    on_exit(fn -> File.rm(speculative_dna) end)

    {:ok, pid} = GenServer.start(StemCell, speculative_dna)
    
    # Monitor the process to detect termination
    ref = Process.monitor(pid)

    # Simulate medium stress spike
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: 0.6, source: "metabolic_daemon"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    send(pid, {:msg, "metabolic.spike", payload})

    assert_receive {:DOWN, ^ref, :process, ^pid, :metabolic_pruning}, 1000
  end

  test "StemCell sheds non-essential synapses on high stress (Digital Torpor)" do
    # Create DNA with multiple synapses
    active_dna = "/tmp/active_dna.yml"
    File.write!(active_dna, """
    cell_type: motor
    allowed_actions: ["move"]
    synapses:
      - type: push
        bind: tcp://127.0.0.1:0
      - type: push
        bind: tcp://127.0.0.1:0
    """)
    on_exit(fn -> File.rm(active_dna) end)

    {:ok, pid} = StemCell.start_link(active_dna)
    
    # Initial state should have 3 synapses (1 nociception + 2 from DNA)
    assert 3 == GenServer.call(pid, :get_synapse_count)
    
    # Simulate high stress spike
    spike = %Karyon.NervousSystem.MetabolicSpike{severity: 1.0, source: "metabolic_daemon"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(spike)
    payload = IO.iodata_to_binary(iodata)
    send(pid, {:msg, "metabolic.spike", payload})

    Process.sleep(200)
    
    # After torpor, it should only have 1 synapse (the essential one)
    assert 1 == GenServer.call(pid, :get_synapse_count)
    assert :torpor == GenServer.call(pid, :get_status)
  end

  test "StemCell forms expectations and calculates VFE on nociception" do
    active_dna = "/tmp/active_dna_2.yml"
    File.write!(active_dna, """
    cell_type: sensor
    synapses: []
    """)
    on_exit(fn -> File.rm(active_dna) end)

    Process.register(self(), :stem_cell_test_observer)

    on_exit(fn ->
      if Process.whereis(:stem_cell_test_observer) == self(), do: Process.unregister(:stem_cell_test_observer)
    end)

    original_module = Application.get_env(:core, :memory_module)
    original_rhizome_module = Application.get_env(:core, :rhizome_module)
    Application.put_env(:core, :memory_module, MemoryStub)
    Application.put_env(:core, :rhizome_module, RhizomeStub)

    on_exit(fn ->
      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end

      if original_rhizome_module do
        Application.put_env(:core, :rhizome_module, original_rhizome_module)
      else
        Application.delete_env(:core, :rhizome_module)
      end
    end)

    {:ok, pid} = StemCell.start_link(active_dna)
    
    # Form an expectation
    :ok =
      GenServer.call(
        pid,
        {:form_expectation, 1001, :low_vfe, 0.8,
         %{
           trace_id: "trace-1001",
           source_step_id: "step-1001",
           source_attractor_id: "attractor-1",
           metadata: %{objective: "latency"}
         }}
      )
    
    # Simulate nociception
    noc_msg = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      source: "telemetry",
      severity: 1.0,
      metadata: %{"error" => "high_latency"}
    }
    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(noc_msg)
    
    send(pid, {:synapse_recv, self(), payload})

    Process.sleep(100)

    assert_receive {:prediction_error_persisted, prediction_error}, 1_000
    assert prediction_error["type"] == "nociception"
    assert prediction_error["status"] == "pruned"
    assert prediction_error["vfe"] == 0.8
    assert prediction_error["cell_id"] == active_dna
    assert prediction_error["source_cell_id"] == ""
    assert prediction_error["timestamp_unit"] == "iso8601"
    assert is_binary(prediction_error["recorded_at"])
    assert is_binary(prediction_error["observed_at"])
    assert prediction_error["metadata"]["schema_version"] == "2026-03-18"
    assert prediction_error["metadata"]["event_source"] == "nociception"
    assert prediction_error["metadata"]["correction_type"] == "prune_pathway"
    assert prediction_error["metadata"]["correction_status"] == "applied"
    assert [%{"from_id" => "step-1001", "to_id" => "attractor-1", "target_kind" => "pathway", "trace_id" => "trace-1001"}] =
             prediction_error["metadata"]["correction_targets"]
    assert [%{"trace_id" => "trace-1001", "objective_weight" => 1.0}] = prediction_error["expectation_lineage"]
    assert_received {:pathway_pruned, pathway}
    assert pathway[:from_id] == "step-1001"
    assert pathway[:to_id] == "attractor-1"
    assert pathway[:weight_delta] == 0.8
    assert :active == GenServer.call(pid, :get_status)
  end

  test "StemCell refuses mutation intents that violate sovereign homeostasis constraints" do
    sovereign_dna = "/tmp/sovereign_dna.yml"

    File.write!(sovereign_dna, """
    cell_type: planner
    allowed_actions: ["execute_plan"]
    synapses: []
    """)

    on_exit(fn -> File.rm(sovereign_dna) end)

    Process.register(self(), :stem_cell_test_observer)

    on_exit(fn ->
      if Process.whereis(:stem_cell_test_observer) == self(), do: Process.unregister(:stem_cell_test_observer)
    end)

    original_module = Application.get_env(:core, :memory_module)
    original_sovereignty = Application.get_env(:core, :sovereignty)
    Application.put_env(:core, :memory_module, MemoryStub)
    Application.put_env(:core, :sovereignty, %{
      "hard_mandates" => %{"preserve_homeostasis" => 1.4},
      "soft_values" => %{"safety" => 1.2},
      "evolving_needs" => %{"continuity" => 1.1},
      "precedence" => %{"hard_mandates" => 1.5}
    })

    on_exit(fn ->
      if original_module, do: Application.put_env(:core, :memory_module, original_module), else: Application.delete_env(:core, :memory_module)
      if original_sovereignty, do: Application.put_env(:core, :sovereignty, original_sovereignty), else: Application.delete_env(:core, :sovereignty)
    end)

    {:ok, pid} = StemCell.start_link(sovereign_dna)

    {:ok, intent} =
      Core.ExecutionIntent.new(%{
        id: "intent:refusal-check",
        action: "execute_plan",
        cell_type: "planner",
        params: %{"steps" => [%{"action" => "patch_codebase"}]},
        default_args: %{},
        executor: %{"module" => "Core.TestSupport.ExecutorStub", "function" => "capture_output"},
        created_at: 1_710_000_030
      })

    assert {:error, {:sovereign_refusal, event}} = GenServer.call(pid, {:execute_intent, intent})
    assert event["decision"] == "refuse"
    assert event["operator_brief"].template_id == "operator.sovereignty.refuse"
    assert_received {:sovereignty_event_persisted, persisted}
    assert persisted["intent_id"] == "intent:refusal-check"
  end

  test "StemCell uses objective weights when calculating variational free energy" do
    weighted_dna = "/tmp/weighted_dna.yml"

    File.write!(weighted_dna, """
    cell_type: sensor
    synapses: []
    """)

    on_exit(fn -> File.rm(weighted_dna) end)

    Process.register(self(), :stem_cell_test_observer)

    on_exit(fn ->
      if Process.whereis(:stem_cell_test_observer) == self(), do: Process.unregister(:stem_cell_test_observer)
    end)

    original_module = Application.get_env(:core, :memory_module)
    Application.put_env(:core, :memory_module, MemoryStub)

    on_exit(fn ->
      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end
    end)

    {:ok, pid} = StemCell.start_link(weighted_dna)

    :ok =
      GenServer.call(
        pid,
        {:form_expectation, "critical-goal", :stability, 0.5,
         %{
           objective_weight: 2.0,
           trace_id: "weighted-trace",
           source_step_id: "weighted-step",
           source_attractor_id: "weighted-attractor",
           metadata: %{objective: "stability"}
         }}
      )

    noc_msg = %Karyon.NervousSystem.PredictionError{
      type: "nociception",
      source: "telemetry",
      severity: 1.0,
      metadata: %{"failed_expectation_id" => "critical-goal", "severity" => "1.0", "trace_id" => "weighted-trace"}
    }

    {:ok, payload} = Karyon.NervousSystem.PredictionError.encode(noc_msg)
    send(pid, {:synapse_recv, self(), payload})

    assert_receive {:prediction_error_persisted, prediction_error}
    assert prediction_error["vfe"] == 1.0
    assert prediction_error["metadata"]["expectation_lineage"] == prediction_error["expectation_lineage"]

    assert [%{"id" => "critical-goal", "trace_id" => "weighted-trace", "objective_weight" => 2.0}] =
             prediction_error["expectation_lineage"]
  end

  test "StemCell correctly dispatches motor actions through a declarative executor contract" do
    specialized_dna = "/tmp/specialized_dna.yml"
    File.write!(specialized_dna, """
    cell_type: specialized_motor
    allowed_actions: ["patch_codebase"]
    executor:
      module: "Core.TestSupport.ExecutorStub"
      function: "capture_output"
    """)
    on_exit(fn -> File.rm(specialized_dna) end)

    {:ok, pid} = StemCell.start_link(specialized_dna)

    original_module = Application.get_env(:core, :memory_module)
    original_rhizome_module = Application.get_env(:core, :rhizome_module)
    Application.put_env(:core, :memory_module, MemoryStub)
    Application.put_env(:core, :rhizome_module, RhizomeStub)
    Process.register(self(), :stem_cell_test_observer)

    on_exit(fn ->
      if Process.whereis(:stem_cell_test_observer) == self(), do: Process.unregister(:stem_cell_test_observer)

      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end

      if original_rhizome_module do
        Application.put_env(:core, :rhizome_module, original_rhizome_module)
      else
        Application.delete_env(:core, :rhizome_module)
      end
    end)

    :ok =
      GenServer.call(
        pid,
        {:form_expectation, "motor-step", :patched, 0.6,
         %{
           source_step_id: "motor-step",
           source_attractor_id: "motor-attractor",
           trace_id: "motor-trace"
         }}
      )

    assert {:ok, %{exit_code: 0, mode: :mock, vm_id: "test_vm", stdout: "mock execution", stderr: ""}} ==
           GenServer.call(pid, {:execute, "patch_codebase", [vm_id: "test_vm"]})

    assert_received {:execution_outcome_persisted, outcome}
    assert_received {:execution_telemetry_persisted, telemetry}
    assert_received {:pathway_reinforced, pathway}
    assert pathway[:from_id] == "motor-step"
    assert pathway[:to_id] == "motor-attractor"
    assert pathway[:weight_delta] == 0.6
    assert outcome["status"] == "success"
    assert String.starts_with?(outcome["execution_intent_id"], "intent:specialized_motor:patch_codebase:")
    assert outcome["action"] == "patch_codebase"
    assert outcome["vm_id"] == "test_vm"
    assert outcome["executor"] == "Core.TestSupport.ExecutorStub.capture_output"
    assert outcome["execution_intent"]["action"] == "patch_codebase"
    assert outcome["execution_intent"]["executor"]["module"] == "Core.TestSupport.ExecutorStub"
    assert outcome["cell_id"] == specialized_dna
    assert outcome["learning_phase"] == "action_feedback"
    assert outcome["learning_edge"] == "action_feedback->plasticity"
    assert outcome["result"]["exit_code"] == 0
    assert telemetry["schema"] == "karyon.execution-telemetry.v1"
    assert telemetry["source_document_id"] == "execution_outcome:#{specialized_dna}:patch_codebase:#{outcome["recorded_at"]}"
    assert "action:patch_codebase" in telemetry["tags"]
    assert telemetry["provenance"]["execution_intent_id"] == outcome["execution_intent_id"]
    assert telemetry["result_summary"]["stdout_present"]
  end

  test "StemCell persists execution failures into the prediction-error pipeline" do
    failure_dna = "/tmp/failure_dna.yml"

    File.write!(failure_dna, """
    id: "failure_cell"
    cell_type: "specialized_motor"
    allowed_actions: ["patch_codebase"]
    executor:
      module: "Core.TestSupport.ExecutorStub"
      function: "simulate_failure"
    """)

    on_exit(fn -> File.rm(failure_dna) end)

    {:ok, pid} = StemCell.start_link(failure_dna)

    original_module = Application.get_env(:core, :memory_module)
    Application.put_env(:core, :memory_module, MemoryStub)
    Process.register(self(), :stem_cell_test_observer)

    on_exit(fn ->
      if Process.whereis(:stem_cell_test_observer) == self(), do: Process.unregister(:stem_cell_test_observer)

      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end
    end)

    assert {:error, :simulated_failure} ==
             GenServer.call(pid, {:execute, "patch_codebase", [vm_id: "failure_vm"]})

    assert_received {:prediction_error_persisted, prediction_error}
    assert prediction_error["type"] == "execution_failure"
    assert prediction_error["status"] == "failure"
    assert prediction_error["cell_id"] == "failure_cell"
    assert prediction_error["learning_phase"] == "prediction_error"
    assert prediction_error["timestamp_unit"] == "iso8601"
    assert is_binary(prediction_error["recorded_at"])
    assert prediction_error["metadata"]["learning_phase"] == "prediction_error"
    assert prediction_error["metadata"]["learning_edge"] == "prediction_error->plasticity"
    assert prediction_error["metadata"]["schema_version"] == "2026-03-18"
    assert prediction_error["metadata"]["correction_type"] == "prune_pathway"
    assert prediction_error["metadata"]["correction_status"] == "applied"
    assert prediction_error["metadata"]["action"] == "patch_codebase"
    assert String.starts_with?(prediction_error["metadata"]["execution_intent_id"], "intent:specialized_motor:patch_codebase:")
    assert prediction_error["metadata"]["execution_intent"]["executor"]["function"] == "simulate_failure"
    assert is_list(prediction_error["expectation_lineage"])
  end

  test "StemCell denies execution when ATP budget is below DNA requirement" do
    constrained_dna = "/tmp/constrained_dna.yml"

    File.write!(constrained_dna, """
    id: "constrained_cell"
    cell_type: "specialized_motor"
    allowed_actions: ["patch_codebase"]
    executor:
      module: "Core.TestSupport.ExecutorStub"
      function: "capture_output"
    atp_requirement: 0.9
    """)

    on_exit(fn -> File.rm(constrained_dna) end)

    {:ok, pid} = StemCell.start_link(constrained_dna)

    high_spike = %Karyon.NervousSystem.MetabolicSpike{severity: 1.0, source: "metabolic_daemon"}
    {:ok, iodata} = Karyon.NervousSystem.MetabolicSpike.encode(high_spike)
    send(pid, {:msg, "metabolic.spike", IO.iodata_to_binary(iodata)})
    Process.sleep(100)

    assert {:error, :insufficient_atp} ==
             GenServer.call(pid, {:execute, "patch_codebase", [vm_id: "budget_vm"]})

    runtime_state = GenServer.call(pid, :get_runtime_state)
    assert runtime_state.atp_metabolism == 0.1
    assert runtime_state.status == :torpor
  end

  @tag :external
  test "StemCell persists real execution outcomes into Rhizome" do
    specialized_dna = "/tmp/specialized_dna_external.yml"

    File.write!(specialized_dna, """
    id: "stem_cell_execution_outcome_test"
    cell_type: specialized_motor
    allowed_actions: ["patch_codebase"]
    executor:
      module: "Core.TestSupport.ExecutorStub"
      function: "capture_output"
    """)

    on_exit(fn -> File.rm(specialized_dna) end)

    original_module = Application.get_env(:core, :memory_module)
    if original_module, do: Application.put_env(:core, :memory_module, original_module), else: Application.delete_env(:core, :memory_module)

    {:ok, pid} = StemCell.start_link(specialized_dna)

    assert {:ok, %{exit_code: 0, mode: :mock, vm_id: "xtdb_vm", stdout: "mock execution", stderr: ""}} ==
             GenServer.call(pid, {:execute, "patch_codebase", [vm_id: "xtdb_vm"]})

    assert {:ok, rows} =
             Rhizome.Native.xtdb_query(%{
               "query" => %{
                 "find" => ["(pull ?e [cell_id action status vm_id executor])"],
                 "where" => [
                   ["?e", "cell_id", "stem_cell_execution_outcome_test"],
                   ["?e", "action", "patch_codebase"]
                 ]
               }
             })

    assert Enum.any?(rows, fn row ->
             row["cell_id"] == "stem_cell_execution_outcome_test" and
               row["status"] == "success" and
               row["vm_id"] == "xtdb_vm" and
               row["executor"] == "Core.TestSupport.ExecutorStub.capture_output"
           end)
  end

  test "StemCell fails to start with malformed DNA" do
    malformed_dna = "/tmp/malformed_dna.yml"
    File.write!(malformed_dna, "::: malformed yaml :::")
    on_exit(fn -> File.rm(malformed_dna) end)

    # Use GenServer.start (unlinked) to avoid exit signal propagation in test
    assert {:error, _} = GenServer.start(StemCell, malformed_dna)
  end

  test "StemCell prunes the active pathway when receiving an STDP prediction error" do
    specialized_dna = "/tmp/stdp_dna.yml"
    File.write!(specialized_dna, """
    cell_type: specialized_motor
    allowed_actions: ["patch_codebase"]
    executor:
      module: "Core.TestSupport.ExecutorStub"
      function: "capture_output"
    """)
    on_exit(fn -> File.rm(specialized_dna) end)

    Process.register(self(), :stem_cell_test_observer)

    on_exit(fn ->
      if Process.whereis(:stem_cell_test_observer) == self(), do: Process.unregister(:stem_cell_test_observer)
    end)

    original_module = Application.get_env(:core, :memory_module)
    original_rhizome_module = Application.get_env(:core, :rhizome_module)
    Application.put_env(:core, :memory_module, MemoryStub)
    Application.put_env(:core, :rhizome_module, RhizomeStub)

    on_exit(fn ->
      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end

      if original_rhizome_module do
        Application.put_env(:core, :rhizome_module, original_rhizome_module)
      else
        Application.delete_env(:core, :rhizome_module)
      end
    end)

    {:ok, pid} = StemCell.start_link(specialized_dna)

    assert {:ok, %{exit_code: 0}} = GenServer.call(pid, {:execute, "patch_codebase", [vm_id: "stdp_vm"]})

    send(pid, {:stdp_prediction_error, specialized_dna, 0.9})

    assert_receive {:stdp_pathway_pruned, event}
    assert event["sensory_id"] == specialized_dna
    assert String.starts_with?(event["motor_id"], "intent:specialized_motor:patch_codebase:")
    assert_receive {:prediction_error_persisted, prediction_error}, 1_000
    assert prediction_error["type"] == "stdp_prediction_error"
    assert prediction_error["metadata"]["sensory_id"] == specialized_dna
    assert prediction_error["metadata"]["motor_action_id"] == event["motor_id"]
    assert prediction_error["status"] == "pruned"
  end
end
