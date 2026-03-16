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
