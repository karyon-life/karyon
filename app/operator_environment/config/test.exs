import Config

config :operator_environment, OperatorEnvironmentWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4102],
  secret_key_base: "4LZHQ6YJHvcv39cps6Lme9NAgceQ8sxv5YV7nHNk6KYEpfEjT8m6TT9icJLdY0cB",
  server: false

config :operator_environment, :start_dns_cluster, false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, enable_expensive_runtime_checks: true
config :phoenix, sort_verified_routes_query_params: true
