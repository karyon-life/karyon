import Config

parse_bool = fn value, default ->
  case value do
    nil -> default
    "1" -> true
    "true" -> true
    "TRUE" -> true
    "yes" -> true
    "on" -> true
    "0" -> false
    "false" -> false
    "FALSE" -> false
    "no" -> false
    "off" -> false
    _ -> default
  end
end

parse_int = fn value, default ->
  case value do
    nil ->
      default

    string ->
      case Integer.parse(string) do
        {parsed, ""} -> parsed
        _ -> default
      end
  end
end

config :protox, :protoc, System.get_env("PROTOC_PATH", "/tmp/protoc/bin/protoc")

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

config :nervous_system,
  nociception_port: parse_int.(System.get_env("KARYON_NOCICEPTION_PORT"), 5555)

config :core,
  strict_preflight: parse_bool.(System.get_env("KARYON_STRICT_PREFLIGHT"), false)

dashboard_server? =
  parse_bool.(System.get_env("KARYON_DASHBOARD_SERVER"), false) or
    parse_bool.(System.get_env("PHX_SERVER"), false)

dashboard_port = parse_int.(System.get_env("PORT"), 4000)
dashboard_host = System.get_env("PHX_HOST", "localhost")
dashboard_scheme = System.get_env("KARYON_DASHBOARD_SCHEME", "http")
dashboard_secret = System.get_env("SECRET_KEY_BASE")

config :dashboard, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY", "localhost")

config :dashboard, DashboardWeb.Endpoint,
  server: dashboard_server?,
  url: [host: dashboard_host, port: dashboard_port, scheme: dashboard_scheme],
  http: [ip: {0, 0, 0, 0}, port: dashboard_port]

if config_env() == :prod do
  if is_nil(dashboard_secret) or dashboard_secret == "" do
    raise """
    environment variable SECRET_KEY_BASE is missing.
    Generate one with: mix phx.gen.secret
    """
  end

  config :dashboard, DashboardWeb.Endpoint,
    secret_key_base: dashboard_secret
end
