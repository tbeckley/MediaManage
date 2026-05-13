import Config

config :mediamanage,
  encode_settings: { :hevc, "medium", 24 },
  max_concurrency: :infinity,
  cache_path: "out/cache",
  cache_interval: 600_000,
  listen_ip: :any,
  http_port: 4000

config :logger,
  level: :info
