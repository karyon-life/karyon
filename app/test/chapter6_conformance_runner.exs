service_commands = [
  {"mix", ["test", "test/core/recovery_chaos_integration_test.exs", "--include", "external"], Path.expand("../core", __DIR__)},
  {"mix", ["test", "test/rhizome/service_integration_test.exs", "--include", "external"], Path.expand("../rhizome", __DIR__)}
]

commands = [
  {"mix", ["test", "test/sensory/spatial_pooler_test.exs", "test/sensory/native_test.exs"], Path.expand("../sensory", __DIR__)},
  {"mix", ["test", "test/nervous_system/pain_receptor_test.exs"], Path.expand("../nervous_system", __DIR__)},
  {"mix", ["test", "test/core/stem_cell_test.exs"], Path.expand("../core", __DIR__)},
  {"mix", ["test", "test/rhizome/consolidation_manager_test.exs", "test/rhizome/sleep_consolidation_test.exs"], Path.expand("../rhizome", __DIR__)}
]

run_command = fn command, args, cd, failure_message ->
  {_, exit_code} =
    System.cmd(command, args,
      cd: cd,
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    )

  if exit_code != 0 do
    Mix.raise(failure_message <> " while running #{command} #{Enum.join(args, " ")}")
  end
end

service_available? = fn ->
  services = Application.get_env(:karyon, :services, [])

  probes = [
    services |> Keyword.get(:memgraph, []) |> Keyword.get(:url, "bolt://127.0.0.1:7687"),
    services |> Keyword.get(:xtdb, []) |> Keyword.get(:url, "postgres://127.0.0.1:5432/xtdb"),
    services |> Keyword.get(:nats, []) |> Keyword.get(:url, "nats://127.0.0.1:4222")
  ]

  probe = fn url ->
    uri = URI.parse(url)
    host = String.to_charlist(uri.host || "127.0.0.1")
    port = uri.port || 0

    case :gen_tcp.connect(host, port, [:binary, active: false], 500) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _reason} ->
        false
    end
  end

  Enum.all?(probes, probe)
end

Enum.each(commands, fn {command, args, cd} ->
  run_command.(command, args, cd, "Chapter 6 conformance failed")
end)

if service_available?.() do
  Enum.each(service_commands, fn {command, args, cd} ->
    run_command.(command, args, cd, "Chapter 6 conformance failed")
  end)
else
  Mix.shell().info("Chapter 6 conformance: external Memgraph/XTDB/NATS services unavailable; skipping service-backed adaptive-map suites.")
end
