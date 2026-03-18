commands = [
  {"mix", ["test", "test/core/dna_control_plane_test.exs", "test/core/preflight_test.exs", "test/core/tier1_cellular_test.exs"], Path.expand("../core", __DIR__)},
  {"mix", ["test", "test/core/epigenetic_supervision_test.exs", "test/core/epigenetic_supervisor_stress_test.exs"], Path.expand("../core", __DIR__)},
  {"mix", ["test", "test/core/cellular_resilience_test.exs", "test/chaos/apoptosis_test.exs", "test/core/metabolic_stress_test.exs", "test/core/stem_cell_test.exs"], Path.expand("../core", __DIR__)}
]

Enum.each(commands, fn {command, args, cd} ->
  {_, exit_code} =
    System.cmd(command, args,
      cd: cd,
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    )

  if exit_code != 0 do
    Mix.raise("Chapter 4 conformance failed while running #{command} #{Enum.join(args, " ")}")
  end
end)
