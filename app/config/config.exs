import Config

config :protox, :protoc, "/tmp/protoc/bin/protoc"

# Dashboard configuration
config :dashboard, DashboardWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: DashboardWeb.ErrorHTML, json: DashboardWeb.ErrorJSON],
    layout: false
  ],
  live_view: [signing_salt: "v8L8L8L8"]

import_config "#{config_env()}.exs"
