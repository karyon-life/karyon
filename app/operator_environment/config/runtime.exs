import Config

if System.get_env("PHX_SERVER") do
  config :operator_environment, OperatorEnvironmentWeb.Endpoint, server: true
end

port =
  System.get_env("KARYON_OPERATOR_ENVIRONMENT_PORT", System.get_env("PORT", "4100"))
  |> String.to_integer()

config :operator_environment, OperatorEnvironmentWeb.Endpoint,
  http: [port: port]

if config_env() == :prod do
  secret_key_base =
    System.get_env("OPERATOR_ENVIRONMENT_SECRET_KEY_BASE") ||
      System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable OPERATOR_ENVIRONMENT_SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("OPERATOR_ENVIRONMENT_HOST") || System.get_env("PHX_HOST") || "example.com"

  config :operator_environment, OperatorEnvironmentWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base
end
