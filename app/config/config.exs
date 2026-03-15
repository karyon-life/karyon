import Config

config :protox, :protoc, "/tmp/protoc/bin/protoc"

import_config "#{config_env()}.exs"
