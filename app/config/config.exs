import Config

config :protox, :protoc, System.get_env("PROTOC_PATH") || System.find_executable("protoc") || "/tmp/protoc/bin/protoc"

config :karyon, :services,
  memgraph: [
    url: "bolt://127.0.0.1:7687",
    username: "memgraph",
    password: ""
  ],
  xtdb: [
    url: "postgres://127.0.0.1:5432/xtdb"
  ],
  nats: [
    url: "nats://127.0.0.1:4222"
  ]

# Dashboard configuration
config :dashboard, DashboardWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: DashboardWeb.ErrorHTML, json: DashboardWeb.ErrorJSON],
    layout: false
  ],
  live_view: [signing_salt: "v8L8L8L8"]

import_config "#{config_env()}.exs"
