commands = [
  {"mix",
   [
     "test",
     "--max-cases",
     "1",
     "test/core/metabolic_tier4_test.exs",
     "test/core/service_health_test.exs",
     "test/core/epigenetic_supervision_test.exs",
     "test/core/motor_driver_test.exs",
     "test/core/epistemic_forager_test.exs",
     "test/core/simulation_daemon_test.exs"
   ], Path.expand("../core", __DIR__), %{}},
  {"mix",
   ["test", "test/rhizome/memory_test.exs"], Path.expand("../rhizome", __DIR__), %{}},
  {"mix",
   ["test", "test/sandbox/executor_test.exs", "test/sandbox/wrs_test.exs"],
   Path.expand("../sandbox", __DIR__), %{}}
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
    Mix.raise("Chapter 9 conformance failed while running #{command} #{Enum.join(args, " ")}")
  end
end)
