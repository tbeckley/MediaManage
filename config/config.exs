import Config

config :mediamanage,
  encode_settings: { :hevc, "medium", 24 },
  max_concurrency: :infinity,
  cache_path: "/tmp/cache",
  cache_interval: 3_600,
  listen_ip: :any,
  http_port: 4000

config :logger,
  level: :info

import_config "env/#{config_env()}.exs"
