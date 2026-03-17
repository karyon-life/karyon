import Config

config :logger, level: :info

config :dashboard, DashboardWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"
