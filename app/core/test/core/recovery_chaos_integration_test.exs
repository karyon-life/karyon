defmodule Core.RecoveryChaosIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :external

  @restart_timeout_ms 5_000
  @poll_interval_ms 50

  defmodule FakeMetabolicDaemon do
    use GenServer

    def start_link(opts \\ []) do
      pressure = Keyword.get(opts, :pressure, :low)
      GenServer.start_link(__MODULE__, pressure, name: Core.MetabolicDaemon)
    end

    def init(pressure), do: {:ok, pressure}
    def handle_call(:get_pressure, _from, pressure), do: {:reply, pressure, pressure}
    def handle_call(:get_policy, _from, pressure), do: {:reply, Core.MetabolismPolicy.build_policy(pressure), pressure}
  end

  setup_all do
    case Core.ServiceHealth.ensure_ready([:memgraph, :xtdb, :nats]) do
      :ok ->
        Enum.each([:telemetry, :jason, :core, :nervous_system, :rhizome, :sensory], fn app ->
          case Application.ensure_all_started(app) do
            {:ok, _} -> :ok
            {:error, {:already_started, _}} -> :ok
            :ok -> :ok
            other -> flunk("failed to start #{app}: #{inspect(other)}")
          end
        end)

        :ok

      {:error, {:dependencies_unready, blocked, report}} ->
        {:ok, skip: "Recovery chaos dependencies unavailable: #{inspect(blocked)} #{inspect(report)}"}
    end
  end

  test "service-backed supervision and apoptosis recovery are measured" do
    restart_results = measure_supervised_component_restarts()
    cell_recovery = measure_cell_apoptosis_recovery()

    report = %{
      recorded_at: DateTime.utc_now(),
      services: Core.ServiceHealth.check_all(),
      supervised_restarts: restart_results,
      cell_recovery: cell_recovery
    }

    artifact_path = artifact_path()
    File.mkdir_p!(Path.dirname(artifact_path))
    File.write!(artifact_path, Jason.encode_to_iodata!(report, pretty: true))

    assert Enum.all?(restart_results, &(&1.recovery_ms <= @restart_timeout_ms))
    assert cell_recovery.recovery_ms <= @restart_timeout_ms
    assert cell_recovery.recovered_beliefs == true
    assert File.exists?(artifact_path)
  end

  defp measure_supervised_component_restarts do
    [
      %{
        label: "core.metabolic_daemon",
        name: Core.MetabolicDaemon,
        verify: &verify_metabolic_daemon/0
      },
      %{
        label: "nervous_system.pain_receptor",
        name: NervousSystem.PainReceptor,
        verify: &verify_pain_receptor/0
      },
      %{
        label: "rhizome.consolidation_manager",
        name: Rhizome.ConsolidationManager,
        verify: &verify_consolidation_manager/0
      }
    ]
    |> Enum.map(fn %{label: label, name: name, verify: verify} ->
      original_pid = Process.whereis(name)
      assert is_pid(original_pid), "expected #{inspect(name)} to be registered"

      started_at = System.monotonic_time(:millisecond)
      Process.exit(original_pid, :kill)

      restarted_pid = wait_for_registered_restart(name, original_pid, @restart_timeout_ms)
      recovery_ms = System.monotonic_time(:millisecond) - started_at

      verify.()
      assert :ok = Core.ServiceHealth.ensure_ready([:memgraph, :xtdb, :nats])

      %{
        component: label,
        original_pid: inspect(original_pid),
        restarted_pid: inspect(restarted_pid),
        recovery_ms: recovery_ms
      }
    end)
  end

  defp measure_cell_apoptosis_recovery do
    with_fake_low_pressure_daemon(fn ->
      dna_path = Path.expand("../../config/genetics/base_stem_cell.yml", __DIR__)

      beliefs = %{
        "source" => "phase6_recovery_chaos",
        "marker" => Integer.to_string(System.unique_integer([:positive])),
        "restored" => "true"
      }

      assert {:ok, %{id: _}} =
               Rhizome.Memory.checkpoint_cell_state(%{
                 "lineage_id" => dna_path,
                 "dna_path" => dna_path,
                 "beliefs" => beliefs,
                 "expectations" => %{},
                 "status" => "active",
                 "atp_metabolism" => 1.0
               })

      {:ok, original_pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)

      on_exit(fn ->
        if Process.alive?(original_pid), do: Core.EpigeneticSupervisor.apoptosis(original_pid)
      end)

      assert_cell_beliefs(original_pid, beliefs)

      started_at = System.monotonic_time(:millisecond)
      :ok = Core.EpigeneticSupervisor.apoptosis(original_pid)
      wait_until(fn -> not Process.alive?(original_pid) end, @restart_timeout_ms)

      {:ok, restarted_pid} = Core.EpigeneticSupervisor.spawn_cell(dna_path)

      on_exit(fn ->
        if Process.alive?(restarted_pid), do: Core.EpigeneticSupervisor.apoptosis(restarted_pid)
      end)

      recovery_ms = System.monotonic_time(:millisecond) - started_at
      assert_cell_beliefs(restarted_pid, beliefs)

      %{
        dna_path: dna_path,
        original_pid: inspect(original_pid),
        restarted_pid: inspect(restarted_pid),
        recovery_ms: recovery_ms,
        recovered_beliefs: true
      }
    end)
  end

  defp with_fake_low_pressure_daemon(fun) do
    original_pid = Process.whereis(Core.MetabolicDaemon)

    if Process.whereis(Core.Supervisor) && is_pid(original_pid) do
      Supervisor.terminate_child(Core.Supervisor, Core.MetabolicDaemon)
      Supervisor.delete_child(Core.Supervisor, Core.MetabolicDaemon)
    end

    {:ok, fake_daemon} = FakeMetabolicDaemon.start_link(pressure: :low)

    try do
      fun.()
    after
      if Process.alive?(fake_daemon), do: GenServer.stop(fake_daemon)

      if Process.whereis(Core.Supervisor) do
        Supervisor.start_child(Core.Supervisor, {Core.MetabolicDaemon, []})
      end
    end
  end

  defp verify_metabolic_daemon do
    pressure = GenServer.call(Core.MetabolicDaemon, :get_pressure)
    assert pressure in [:low, :medium, :high]
  end

  defp verify_pain_receptor do
    pain_receptor = Process.whereis(NervousSystem.PainReceptor)
    pain_synapse = Process.whereis(:pain_synapse)

    assert is_pid(pain_receptor)
    assert is_pid(pain_synapse)
    assert Process.alive?(pain_synapse)

    NervousSystem.PainReceptor.trigger_nociception(%{module: Core.RecoveryChaosIntegrationTest, reason: "restart_probe"})

    metadata =
      wait_until(
        fn ->
          case :sys.get_state(pain_receptor) do
            %{last_emitted_pain: %{} = metadata} -> {:ok, metadata}
            _ -> :retry
          end
        end,
        @restart_timeout_ms
      )

    assert Map.get(metadata, "schema_version") == "2026-03-18"
    assert Map.get(metadata, "correction_type") == "pending_graph_correction"
    assert Map.get(metadata, "correction_status") == "pending"
    assert Map.get(metadata, "learning_phase") == "prediction_error"
  end

  defp verify_consolidation_manager do
    state = :sys.get_state(Rhizome.ConsolidationManager)

    assert is_map(state)
    assert Map.has_key?(state, :last_consolidation)
  end

  defp assert_cell_beliefs(pid, beliefs) do
    state = :sys.get_state(pid)

    assert Map.take(state.beliefs, Map.keys(beliefs)) == beliefs
  end

  defp wait_for_registered_restart(name, previous_pid, timeout_ms) do
    wait_until(
      fn ->
        case Process.whereis(name) do
          pid when is_pid(pid) ->
            if pid != previous_pid and Process.alive?(pid) do
              {:ok, pid}
            else
              :retry
            end

          _ -> :retry
        end
      end,
      timeout_ms
    )
  end

  defp wait_until(fun, timeout_ms, interval_ms \\ @poll_interval_ms)

  defp wait_until(fun, timeout_ms, _interval_ms) when timeout_ms <= 0 do
    case fun.() do
      true -> :ok
      {:ok, value} -> value
      other -> flunk("timed out waiting for condition, last result: #{inspect(other)}")
    end
  end

  defp wait_until(fun, timeout_ms, interval_ms) do
    case fun.() do
      true ->
        :ok

      {:ok, value} ->
        value

      :retry ->
        Process.sleep(interval_ms)
        wait_until(fun, timeout_ms - interval_ms, interval_ms)

      false ->
        Process.sleep(interval_ms)
        wait_until(fun, timeout_ms - interval_ms, interval_ms)

      other ->
        flunk("unexpected wait result: #{inspect(other)}")
    end
  end

  defp artifact_path do
    date = Date.utc_today() |> Date.to_iso8601() |> String.replace("-", "")
    Path.expand("../../../artifacts/benchmarks/phase6_recovery_#{date}.json", __DIR__)
  end
end
