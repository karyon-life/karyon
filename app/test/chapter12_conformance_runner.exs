commands = [
  {"mix",
   [
     "test",
     "--max-cases",
     "1",
     "test/core/maturation_lifecycle_test.exs",
     "test/core/execution_telemetry_test.exs",
     "test/core/teacher_daemon_test.exs",
     "test/core/abstract_intent_test.exs"
   ], Path.expand("../core", __DIR__), %{}},
  {"mix",
   [
     "test",
     "test/sensory/baseline_diet_test.exs",
     "test/sensory/eyes_test.exs"
   ], Path.expand("../sensory", __DIR__), %{}},
  {"mix",
   [
     "test",
     "test/rhizome/memory_test.exs",
     "test/rhizome_test.exs"
   ], Path.expand("../rhizome", __DIR__), %{}}
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
    Mix.raise("Chapter 12 conformance failed while running #{command} #{Enum.join(args, " ")}")
  end
end)
