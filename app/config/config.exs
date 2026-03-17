import Config

config :protox, :protoc, "/tmp/protoc/bin/protoc"

config :sandbox,
  firecracker_binary: System.get_env("KARYON_FIRECRACKER_BINARY", "/usr/local/bin/firecracker"),
  kernel_image_path: System.get_env("KARYON_FIRECRACKER_KERNEL"),
  rootfs_path: System.get_env("KARYON_FIRECRACKER_ROOTFS")

config :karyon, :services,
  memgraph: [
    url: System.get_env("KARYON_MEMGRAPH_URL", "bolt://127.0.0.1:7687"),
    username: System.get_env("KARYON_MEMGRAPH_USERNAME", "memgraph"),
    password: System.get_env("KARYON_MEMGRAPH_PASSWORD", "")
  ],
  xtdb: [
    url: System.get_env("KARYON_XTDB_URL", "postgres://127.0.0.1:5432/xtdb")
  ],
  nats: [
    url: System.get_env("KARYON_NATS_URL", "nats://127.0.0.1:4222")
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
