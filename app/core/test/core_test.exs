defmodule CoreTest do
  use ExUnit.Case

  test "metabolic daemon monitors CPU run queues" do
    # Allow some time for setup and retry a few times in case of race with other tests
    is_running = 
      Enum.find_value(1..10, fn _ ->
        if Process.whereis(Core.MetabolicDaemon), do: true, else: (Process.sleep(100); false)
      end)
    assert is_running == true
  end

  test "epigenetic rejection: invalid YAML crashes the spawn process" do
    # We expect an error when the YAML is malformed
    bad_yaml_path = "/tmp/bad_dna.yml"
    File.write!(bad_yaml_path, "invalid: [unclosed bracket")
    
    # DynamicSupervisor.start_child should return {:error, _} because the cell's init/1 crashes.
    assert {:error, _} = Core.EpigeneticSupervisor.spawn_cell(bad_yaml_path)
  end

  test "stem cell boots with synapses from DNA" do
    dna_path = "/tmp/good_dna.yml"
    dna_content = """
    cell_type: sensory
    synapses:
      - type: push
        bind: tcp://127.0.0.1:5555
    """
    File.write!(dna_path, dna_content)

    assert {:ok, pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)
    assert Process.alive?(pid)
  end
end
