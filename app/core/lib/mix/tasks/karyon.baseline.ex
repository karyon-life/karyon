defmodule Mix.Tasks.Karyon.Baseline do
  use Mix.Task

  @shortdoc "Run the Phase 6 baseline benchmark suite and write a JSON artifact"

  @moduledoc """
  Runs a repeatable local baseline for:

  - cell spawn throughput
  - synapse messaging throughput and latency
  - sensory parse throughput
  - consolidation orchestration cost

  Outputs a JSON artifact under `artifacts/benchmarks/`.
  """

  @default_spawn_count 500
  @default_message_count 1_000
  @default_parse_iterations 200
  @default_consolidation_iterations 50
  @default_output_dir "artifacts/benchmarks"

  def run(args) do
    Mix.Task.run("compile")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          spawn_count: :integer,
          message_count: :integer,
          parse_iterations: :integer,
          consolidation_iterations: :integer,
          output: :string
        ]
      )

    start_apps()
    ensure_stress_tester()

    spawn_count = Keyword.get(opts, :spawn_count, @default_spawn_count)
    message_count = Keyword.get(opts, :message_count, @default_message_count)
    parse_iterations = Keyword.get(opts, :parse_iterations, @default_parse_iterations)
    consolidation_iterations = Keyword.get(opts, :consolidation_iterations, @default_consolidation_iterations)

    results = %{
      recorded_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      environment: environment_metadata(),
      configuration: %{
        spawn_count: spawn_count,
        message_count: message_count,
        parse_iterations: parse_iterations,
        consolidation_iterations: consolidation_iterations
      },
      metrics: %{
        cell_spawn: measure_cell_spawn(spawn_count),
        messaging: measure_messaging(message_count),
        sensory_parse: measure_sensory_parse(parse_iterations),
        consolidation: measure_consolidation(consolidation_iterations)
      }
    }

    output_path = write_results(results, Keyword.get(opts, :output))
    Mix.shell().info("Baseline results written to #{output_path}")
  end

  defp start_apps do
    Enum.each([:nervous_system, :rhizome, :sandbox, :sensory, :core, :dashboard], fn app ->
      {:ok, _} = Application.ensure_all_started(app)
    end)
  end

  defp ensure_stress_tester do
    if is_nil(Process.whereis(Core.StressTester)) do
      {:ok, _pid} = Core.StressTester.start_link()
    end
  end

  defp measure_cell_spawn(spawn_count) do
    dna_path = Path.expand("core/priv/dna/architect_planner.yml", File.cwd!())
    {duration_us, {:ok, count}} = timed(fn -> Core.StressTester.swarm_spawn(spawn_count, dna_path) end)
    pressure = GenServer.call(Core.MetabolicDaemon, :get_pressure)
    run_queue = :erlang.statistics(:run_queue)
    Core.StressTester.purge()

    %{
      spawned: count,
      duration_ms: round(duration_us / 1_000),
      cells_per_second: rate_per_second(count, duration_us),
      pressure_after_spawn: Atom.to_string(pressure),
      run_queue_after_spawn: run_queue
    }
  end

  defp measure_messaging(message_count) do
    {:ok, pull} = NervousSystem.Synapse.start_link(type: :pull, owner: self())
    {:ok, port} = GenServer.call(pull, :get_port)
    {:ok, push} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:#{port}", action: :connect)
    Process.sleep(100)

    {duration_us, :ok} =
      timed(fn ->
        Enum.each(1..message_count, fn idx ->
          :ok = NervousSystem.Synapse.send_signal(push, Integer.to_string(idx))
        end)

        Enum.each(1..message_count, fn idx ->
          assert_receive_message(pull, Integer.to_string(idx))
        end)
      end)

    GenServer.stop(push)
    GenServer.stop(pull)

    %{
      messages: message_count,
      duration_ms: round(duration_us / 1_000),
      messages_per_second: rate_per_second(message_count, duration_us),
      avg_end_to_end_latency_us: Float.round(duration_us / message_count, 2)
    }
  end

  defp measure_sensory_parse(parse_iterations) do
    code = """
    def hello():
        print("world")
    """

    Sensory.Native.parse_to_graph("python", code)

    {duration_us, last_result} =
      timed(fn ->
        Enum.reduce(1..parse_iterations, nil, fn _, _ ->
          Sensory.Native.parse_to_graph("python", code)
        end)
      end)

    %{
      iterations: parse_iterations,
      duration_ms: round(duration_us / 1_000),
      ops_per_second: rate_per_second(parse_iterations, duration_us),
      avg_parse_latency_ms: Float.round(duration_us / parse_iterations / 1_000, 3),
      sample_size_bytes: byte_size(code),
      sample_verified: String.contains?(last_result, "hello")
    }
  end

  defp measure_consolidation(iterations) do
    {duration_us, durations} =
      timed(fn ->
        Enum.map(1..iterations, fn _ ->
          Rhizome.ConsolidationManager.run_once(
            native_module: __MODULE__.ConsolidationNativeStub,
            schedule_next?: false,
            logger_fun: fn _ -> :ok end
          ).duration_ms
        end)
      end)

    avg_ms =
      if durations == [] do
        0.0
      else
        durations |> Enum.sum() |> Kernel./(length(durations)) |> Float.round(3)
      end

    %{
      iterations: iterations,
      total_duration_ms: round(duration_us / 1_000),
      avg_cycle_ms: avg_ms,
      min_cycle_ms: Enum.min(durations, fn -> 0 end),
      max_cycle_ms: Enum.max(durations, fn -> 0 end),
      mode: "stubbed_control_plane"
    }
  end

  defp environment_metadata do
    %{
      mix_env: to_string(Mix.env()),
      otp_release: List.to_string(:erlang.system_info(:otp_release)),
      elixir: System.version(),
      schedulers_online: :erlang.system_info(:schedulers_online),
      system_architecture: List.to_string(:erlang.system_info(:system_architecture))
    }
  end

  defp write_results(results, nil) do
    File.mkdir_p!(@default_output_dir)
    filename = "phase6_baseline_#{timestamp_fragment()}.json"
    path = Path.join(@default_output_dir, filename)
    File.write!(path, Jason.encode_to_iodata!(results, pretty: true))
    path
  end

  defp write_results(results, output_path) do
    output_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(output_path, Jason.encode_to_iodata!(results, pretty: true))
    output_path
  end

  defp timestamp_fragment do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.replace(~r/[^0-9]/, "")
  end

  defp timed(fun) do
    started_at = System.monotonic_time(:microsecond)
    result = fun.()
    {System.monotonic_time(:microsecond) - started_at, result}
  end

  defp rate_per_second(units, duration_us) when duration_us > 0 do
    Float.round(units * 1_000_000 / duration_us, 2)
  end

  defp rate_per_second(_units, _duration_us), do: 0.0

  defp assert_receive_message(pull, payload) do
    receive do
      {:synapse_recv, ^pull, ^payload} -> :ok
    after
      5_000 -> raise "timed out waiting for synapse payload #{payload}"
    end
  end

  defmodule ConsolidationNativeStub do
    def bridge_to_xtdb, do: {:ok, %{archived_count: 0, message: "stubbed"}}
    def optimize_graph, do: {:ok, "stubbed"}
    def memgraph_query(_query), do: {:ok, []}
  end
end
