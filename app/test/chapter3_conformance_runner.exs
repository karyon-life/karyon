commands = [
  {"subsystem.contracts", [], Path.expand("..", __DIR__)},
  {"mix",
   [
     "test",
     "test/core/microkernel_sterility_test.exs",
     "test/core/cytoplasm_conformance_test.exs",
     "test/core/tier5_global_test.exs"
   ], Path.expand("../core", __DIR__), %{}},
  {"mix", ["test", "test/sandbox"], Path.expand("../sandbox", __DIR__), %{}},
  {"mix", ["test", "test/nervous_system"], Path.expand("../nervous_system", __DIR__), %{}},
  {"mix",
   [
     "test",
     "test/rhizome/nif_test.exs",
     "test/rhizome/nif_contract_test.exs",
     "test/rhizome/scheduler_test.exs",
     "test/rhizome/memory_test.exs"
   ], Path.expand("../rhizome", __DIR__), %{}}
]

Enum.each(commands, fn
  {"subsystem.contracts", args, cd} ->
    {_, exit_code} =
      System.cmd("mix", ["subsystem.contracts" | args],
        cd: cd,
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    if exit_code != 0, do: Mix.raise("Chapter 3 conformance failed in subsystem contracts")

  {command, args, cd, env} ->
    {_, exit_code} =
      System.cmd(command, args,
        cd: cd,
        env: env,
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    if exit_code != 0 do
      Mix.raise("Chapter 3 conformance failed while running #{command} #{Enum.join(args, " ")}")
    end
end)
