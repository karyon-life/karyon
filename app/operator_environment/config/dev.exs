import Config

config :operator_environment, OperatorEnvironmentWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "TbI1bxYrwzX6QgfIUJKSy89Rshm6FQ3g0LJ5A+JiOO9tR0wFh9KaEZmrA2zvKknI",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:operator_environment, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:operator_environment, ~w(--watch)]}
  ]

config :operator_environment, OperatorEnvironmentWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
      ~r"lib/operator_environment_web/router\.ex$"E,
      ~r"lib/operator_environment_web/(controllers|live|components)/.*\.(ex|heex)$"E
    ]
  ]

config :operator_environment, dev_routes: true
config :logger, :default_formatter, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
