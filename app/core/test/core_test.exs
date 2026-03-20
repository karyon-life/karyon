defmodule CoreTest do
  use ExUnit.Case

  test "metabolic daemon monitors CPU run queues" do
    pid =
      Process.whereis(Core.MetabolicDaemon) ||
        start_supervised!(
          {Core.MetabolicDaemon,
           poll_interval_ms: 50, calibration_delay_ms: 0, strict_preflight: false}
        )

    assert is_pid(pid)
    assert %{pressure: pressure} = GenServer.call(pid, :get_runtime_status)
    assert pressure in [:low, :medium, :high]
  end

  test "epigenetic rejection: invalid YAML raises during DNA transcription" do
    bad_yaml_path = "/tmp/bad_dna.yml"
    File.write!(bad_yaml_path, "invalid: [unclosed bracket")

    on_exit(fn -> File.rm(bad_yaml_path) end)

    assert_raise YamlElixir.ParsingError, fn ->
      Core.DNA.load!(bad_yaml_path)
    end
  end

  test "stem cell boots from declarative DNA" do
    dna_path = "/tmp/good_dna.yml"
    dna_content = """
    cell_type: sensory
    synapses:
      - type: push
        bind: tcp://127.0.0.1:5555
    """
    File.write!(dna_path, dna_content)

    on_exit(fn -> File.rm(dna_path) end)

    assert {:ok, pid} = Core.StemCell.start_link(dna_path)
    assert Process.alive?(pid)
    assert GenServer.call(pid, :get_synapse_count) > 0
  end
end
