defmodule Core.StateRecoveryTest do
  use ExUnit.Case, async: false

  alias Core.EpigeneticSupervisor

  defmodule MemoryStub do
    use Agent

    def start_link(_opts) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def reset do
      Agent.update(__MODULE__, fn _ -> %{} end)
    end

    def load_cell_state(lineage_id) do
      Agent.get(__MODULE__, fn state ->
        case Map.fetch(state, {:cell_state, lineage_id}) do
          {:ok, snapshot} -> {:ok, snapshot}
          :error -> {:error, :not_found}
        end
      end)
    end

    def checkpoint_cell_state(snapshot) do
      lineage_id = snapshot["lineage_id"]

      Agent.update(__MODULE__, fn state ->
        Map.put(state, {:cell_state, lineage_id}, snapshot)
      end)

      {:ok, %{id: "cell_state:#{lineage_id}"}}
    end

    def submit_prediction_error(_prediction_error), do: {:ok, %{id: "prediction_error"}}

    def submit_execution_outcome(outcome) do
      {:ok, %{id: outcome["cell_id"]}}
    end

    def submit_execution_telemetry(telemetry) do
      {:ok, %{id: telemetry["telemetry_id"] || "execution_telemetry"}}
    end

    def submit_differentiation_event(event) do
      {:ok, %{id: event["lineage_id"] || "differentiation_event"}}
    end
  end

  @dna_path "/tmp/state_recovery_cell.yml"

  setup do
    unless Process.whereis(MemoryStub) do
      start_supervised!(MemoryStub)
    end

    MemoryStub.reset()

    case GenServer.whereis(Core.MetabolicDaemon) do
      nil ->
        :ok

      _pid ->
        Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
        Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end

    for {_, pid, _, _} <- DynamicSupervisor.which_children(EpigeneticSupervisor) do
      DynamicSupervisor.terminate_child(EpigeneticSupervisor, pid)
    end

    original_module = Application.get_env(:core, :memory_module)
    Application.put_env(:core, :memory_module, MemoryStub)

    File.write!(@dna_path, """
    id: "recoverable_cell"
    cell_type: "orchestrator"
    allowed_actions:
      - "capture_output"
    synapses: []
    """)

    on_exit(fn ->
      File.rm(@dna_path)

      Supervisor.start_child(Core.Supervisor, Core.MetabolicDaemon)

      if original_module do
        Application.put_env(:core, :memory_module, original_module)
      else
        Application.delete_env(:core, :memory_module)
      end
    end)

    :ok
  end

  test "cell recovers beliefs and expectations from durable lineage state after apoptosis" do
    {:ok, pid1} = EpigeneticSupervisor.spawn_cell(@dna_path)

    :ok = GenServer.call(pid1, {:form_expectation, "edge-1", "checkpoint", 0.8})

    nociception =
      %Karyon.NervousSystem.PredictionError{
        type: "nociception",
        metadata: %{"error" => "timeout"}
      }
      |> Karyon.NervousSystem.PredictionError.encode!()

    send(pid1, {:synapse_recv, self(), nociception})
    Process.sleep(100)

    first_state = GenServer.call(pid1, :get_runtime_state)
    assert first_state.lineage_id == "recoverable_cell"
    assert first_state.beliefs[:last_vfe] == 0.8
    assert first_state.expectations == %{}

    :ok = EpigeneticSupervisor.apoptosis(pid1)
    Process.sleep(100)

    {:ok, pid2} = EpigeneticSupervisor.spawn_cell(@dna_path)
    recovered_state = GenServer.call(pid2, :get_runtime_state)

    assert recovered_state.lineage_id == "recoverable_cell"
    assert recovered_state.beliefs["last_vfe"] == 0.8
    assert recovered_state.atp_metabolism == 1.0
    assert recovered_state.status == :active
  end
end
