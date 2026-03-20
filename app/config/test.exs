import Config

config :nervous_system,
  nociception_port: 5556

# Bypass strict hardware checks during testing
System.put_env("KARYON_MOCK_HARDWARE", "1")

# Dashboard test config
config :dashboard, DashboardWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  server: false

config :dashboard, :start_dns_cluster, false

config :operator_environment, OperatorEnvironmentWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4102],
  secret_key_base: "4LZHQ6YJHvcv39cps6Lme9NAgceQ8sxv5YV7nHNk6KYEpfEjT8m6TT9icJLdY0cB",
  server: false

config :operator_environment, :start_dns_cluster, false
