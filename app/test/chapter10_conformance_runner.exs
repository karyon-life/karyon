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
     "test/core/metabolism_policy_test.exs",
     "test/core/sovereignty_test.exs",
     "test/core/objective_manifest_test.exs",
     "test/core/sovereign_guard_test.exs",
      "test/core/operator_output_test.exs",
      "test/core/cross_workspace_architect_test.exs"
   ], Path.expand("../core", __DIR__), %{}},
  {"mix",
   [
     "test",
     "--max-cases",
     "1",
     "test/core/stem_cell_test.exs"
   ], Path.expand("../core", __DIR__), %{}},
  {"mix",
   ["test", "test/rhizome/memory_test.exs"], Path.expand("../rhizome", __DIR__), %{}},
  {"mix",
   ["test", "test/dashboard/operator_negotiation_test.exs", "test/dashboard/operator_feedback_test.exs"],
   Path.expand("../dashboard", __DIR__), %{"PATH" => path}}
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
    Mix.raise("Chapter 10 conformance failed while running #{command} #{Enum.join(args, " ")}")
  end
end)
