service_commands = [
  {"mix", ["test", "test/rhizome/temporal_query_test.exs", "--include", "external"], Path.expand("../rhizome", __DIR__)},
  {"mix", ["test", "test/rhizome/service_integration_test.exs", "--include", "external"], Path.expand("../rhizome", __DIR__)},
  {"mix", ["test", "test/property/memory_consistency_test.exs", "--include", "external"], Path.expand("../rhizome", __DIR__)}
]

commands = [
  {"mix", ["test", "test/rhizome/memory_test.exs", "test/rhizome/bitemporal_test.exs", "test/rhizome_test.exs"], Path.expand("../rhizome", __DIR__)}
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
  memgraph_url = services |> Keyword.get(:memgraph, []) |> Keyword.get(:url, "bolt://127.0.0.1:7687")
  xtdb_url = services |> Keyword.get(:xtdb, []) |> Keyword.get(:url, "postgres://127.0.0.1:5432/xtdb")

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

  probe.(memgraph_url) and probe.(xtdb_url)
end

Enum.each(commands, fn {command, args, cd} ->
  run_command.(command, args, cd, "Chapter 5 conformance failed")
end)

if service_available?.() do
  Enum.each(service_commands, fn {command, args, cd} ->
    run_command.(command, args, cd, "Chapter 5 conformance failed")
  end)
else
  Mix.shell().info("Chapter 5 conformance: external Memgraph/XTDB services unavailable; skipping service-backed temporal suites.")
end
