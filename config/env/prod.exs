import Config

config :mediamanage,
  cache_path: "/tmp/mediamanage_cache",
  cache_interval: 600,
    listen_ip: :any

config :logger,
  level: :warning
