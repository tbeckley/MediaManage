import Config

config :mediamanage,
  max_concurrency: 2,
  cache_path: "out/cache",
  cache_interval: 600,
  listen_ip: :loopback

config :logger,
  level: :debug
