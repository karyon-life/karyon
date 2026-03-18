commands = [
  {"mix",
   [
     "test",
     "test/sensory/perimeter_test.exs",
     "test/sensory/stream_test.exs",
     "test/sensory/eyes_test.exs",
     "test/sensory/ast_accuracy_test.exs",
     "test/sensory/perception_fidelity_test.exs",
     "test/sensory/ears_test.exs",
     "test/sensory/skin_test.exs",
     "test/sensory/spatial_pooler_test.exs",
     "test/sensory/quantizer_test.exs"
   ], Path.expand("../sensory", __DIR__)}
]

Enum.each(commands, fn {command, args, cd} ->
  {_, exit_code} =
    System.cmd(command, args,
      cd: cd,
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    )

  if exit_code != 0 do
    Mix.raise("Chapter 7 conformance failed while running #{command} #{Enum.join(args, " ")}")
  end
end)
