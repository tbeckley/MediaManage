import Config

if max_concurrency_raw = System.get_env("CONCURRENCY") do
  config :mediamanage,
    max_concurrency: String.to_integer(max_concurrency_raw)
end

if encode_opts_raw = System.get_env("ENCODING") do
  encode_opts = case encode_opts_raw |> String.downcase() |> String.split(",") do
    [ "hevc", preset, crf ] -> { :hevc, preset, crf }
    [ "hevc" ] -> { :hevc, "medium", 24}
    _ -> raise "Unknown encoding options: #{inspect(encode_opts_raw)}"
  end

  config :mediamanage,
    encode_opts: encode_opts
end

if cachepath = System.get_env("CACHEPATH") do
  # TODO - Check if this directory is even valid...
  config :mediamanage,
    cache_path: cachepath
end

if log_level_raw = System.get_env("LOGLEVEL") do
  # I have no idea if this is necessary but I heard never to do String.to_atom() so...
  log_level = case String.downcase(log_level_raw) do
    "error" -> :error
    "warning" -> :warning
    "info" -> :info
    "debug" -> :debug
    "trace" -> :trace
    _ -> IO.puts(:stderr, "Unknown log level #{log_level_raw}, using :info")
      :info
  end

  config :logger,
    level: log_level
end
