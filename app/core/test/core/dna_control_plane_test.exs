defmodule Core.DNAControlPlaneTest do
  use ExUnit.Case

  alias Core.DNA

  test "DNA normalization yields an explicit control-plane contract" do
    dna_path = "/tmp/dna_control_plane_test.yml"

    File.write!(dna_path, """
    id: planner-alpha
    cell_type: architect_planner
    allowed_actions:
      - form_expectation
      - sequence_tasks
    utility_threshold: 0.25
    precision_baseline: 0.8
    atp_requirement: 0.4
    synapses:
      - type: push
        bind: tcp://127.0.0.1:0
    """)

    on_exit(fn -> File.rm(dna_path) end)

    dna = DNA.load!(dna_path)

    assert dna.id == "planner-alpha"
    assert dna.cell_type == "architect_planner"
    assert dna.allowed_actions == ["form_expectation", "sequence_tasks"]
    assert dna.control_plane.lineage_id == "planner-alpha"
    assert dna.control_plane.differentiation_role == :architect_planner
    assert dna.control_plane.metabolism.atp_requirement == 0.4
    assert dna.control_plane.metabolism.utility_threshold == 0.25
    refute dna.control_plane.apoptosis.speculative
    assert dna.control_plane.learning.precision_baseline == 0.8
  end

  test "invalid DNA without a cell_type fails fast" do
    dna_path = "/tmp/dna_missing_cell_type.yml"

    File.write!(dna_path, """
    allowed_actions:
      - ingest_to_memgraph
    """)

    on_exit(fn -> File.rm(dna_path) end)

    assert_raise ArgumentError, ~r/missing required cell_type/, fn ->
      DNA.load!(dna_path)
    end
  end

  test "DNA inheritance applies parent defaults while allowing child overrides" do
    parent_path = "/tmp/dna_parent.yml"
    child_path = "/tmp/dna_child.yml"

    File.write!(parent_path, """
    schema_version: 1
    cell_type: motor
    allowed_actions:
      - compile
      - test
    utility_threshold: 0.6
    precision_baseline: 0.7
    atp_requirement: 0.2
    synapses:
      - type: push
        bind: tcp://127.0.0.1:0
    executor:
      module: Sandbox.Executor
      function: capture_output
    """)

    File.write!(child_path, """
    extends: dna_parent.yml
    id: motor-child
    cell_type: motor_executor
    allowed_actions:
      - patch_codebase
    atp_requirement: 0.5
    """)

    on_exit(fn ->
      File.rm(parent_path)
      File.rm(child_path)
    end)

    dna = DNA.load!(child_path)

    assert dna.schema_version == 1
    assert dna.id == "motor-child"
    assert dna.extends == "dna_parent.yml"
    assert dna.cell_type == "motor_executor"
    assert dna.allowed_actions == ["patch_codebase"]
    assert dna.utility_threshold == 0.6
    assert dna.precision_baseline == 0.7
    assert dna.atp_requirement == 0.5
    assert dna.executor == %{
             "module" => "Sandbox.Executor",
             "function" => "capture_output",
             "default_args" => %{}
           }
  end

  test "legacy motor_executor aliases normalize into the structured executor contract" do
    dna_path = "/tmp/dna_legacy_executor.yml"

    File.write!(dna_path, """
    cell_type: motor
    allowed_actions:
      - execute_script
    motor_executor: firecracker_python
    """)

    on_exit(fn -> File.rm(dna_path) end)

    dna = DNA.load!(dna_path)

    assert dna.executor == %{
             "module" => "Sandbox.Executor",
             "function" => "capture_output",
             "default_args" => %{}
           }
  end
end
