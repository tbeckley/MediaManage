import Config

config :mediamanage,
  encode_settings: { :hevc, "medium", 24 },
  max_concurrency: :infinity,
  cache_path: "out/cache"

config :logger,
  level: :info
