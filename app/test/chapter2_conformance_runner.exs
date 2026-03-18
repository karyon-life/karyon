commands = [
  {"biology.invariants", [], Path.expand("..", __DIR__)},
  {"mix", ["test", "test/core/chapter2_conformance_test.exs", "test/core/epigenetic_supervision_test.exs", "test/core/epigenetic_supervisor_stress_test.exs", "test/core/stem_cell_test.exs", "test/core/motor_driver_test.exs"], Path.expand("../core", __DIR__)},
  {"mix", ["test", "test/nervous_system/pain_receptor_test.exs"], Path.expand("../nervous_system", __DIR__)},
  {"mix", ["test", "test/rhizome/memory_test.exs", "test/rhizome/nif_test.exs"], Path.expand("../rhizome", __DIR__)}
]

Enum.each(commands, fn
  {"biology.invariants", args, cd} ->
    {_, exit_code} = System.cmd("mix", ["biology.invariants" | args], cd: cd, into: IO.stream(:stdio, :line), stderr_to_stdout: true)
    if exit_code != 0, do: Mix.raise("Chapter 2 conformance failed in biology invariants")

  {command, args, cd} ->
    {_, exit_code} = System.cmd(command, args, cd: cd, into: IO.stream(:stdio, :line), stderr_to_stdout: true)
    if exit_code != 0, do: Mix.raise("Chapter 2 conformance failed while running #{command} #{Enum.join(args, " ")}")
end)
