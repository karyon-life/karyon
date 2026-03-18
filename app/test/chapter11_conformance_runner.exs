path =
  ["/tmp/protoc/bin", System.get_env("PATH", "")]
  |> Enum.reject(&(&1 == ""))
  |> Enum.join(":")

commands = [
  {"mix",
   [
     "test",
     "--max-cases",
     "1",
     "test/core/operational_maturity_test.exs",
     "test/core/monorepo_pipeline_test.exs",
     "test/core/engram_test.exs",
     "test/core/tier5_global_test.exs"
   ], Path.expand("../core", __DIR__), %{}},
  {"mix",
   [
     "test",
     "test/dashboard/organism_observability_test.exs",
     "test/dashboard_web/controllers/health_controller_test.exs",
     "test/dashboard_web/live/metabolic_live/index_test.exs"
   ], Path.expand("../dashboard", __DIR__), %{"PATH" => path}}
]

Enum.each(commands, fn {command, args, cd, env} ->
  {_, exit_code} =
    System.cmd(command, args,
      cd: cd,
      env: env,
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    )

  if exit_code != 0 do
    Mix.raise("Chapter 11 conformance failed while running #{command} #{Enum.join(args, " ")}")
  end
end)
