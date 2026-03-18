dashboard_env = fn ->
  fallback_protoc = "/tmp/protoc/bin"
  current_path = System.get_env("PATH", "")

  path =
    if File.exists?(Path.join(fallback_protoc, "protoc")) do
      "#{fallback_protoc}:#{current_path}"
    else
      current_path
    end

  [{"PATH", path}]
end

commands = [
  {"mix",
   [
     "test",
     "test/core/motor_driver_test.exs",
     "test/core/stem_cell_test.exs",
     "test/core/operator_output_test.exs",
     "test/core/operator_feedback_test.exs"
   ], Path.expand("../core", __DIR__), %{}},
  {"mix",
   [
     "test",
     "test/sandbox/executor_test.exs",
     "test/sandbox/wrs_test.exs",
     "test/sandbox/provisioner_test.exs",
     "test/sandbox/security_audit_test.exs",
     "test/sandbox/security_isolation_test.exs"
   ], Path.expand("../sandbox", __DIR__), %{}},
  {"mix",
   ["test", "test/rhizome/memory_test.exs"], Path.expand("../rhizome", __DIR__), %{}},
  {"mix",
   [
     "test",
     "test/dashboard/operator_feedback_test.exs",
     "test/dashboard_web/controllers/health_controller_test.exs"
   ], Path.expand("../dashboard", __DIR__), dashboard_env.()}
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
    Mix.raise("Chapter 8 conformance failed while running #{command} #{Enum.join(args, " ")}")
  end
end)
