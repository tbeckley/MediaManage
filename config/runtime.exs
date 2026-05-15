import Config
require Logger

if max_concurrency_raw = System.get_env("CONCURRENCY") do
  config :mediamanage,
    max_concurrency: String.to_integer(max_concurrency_raw)
end

if encode_opts_raw = System.get_env("ENCODING") do
  encode_opts = case encode_opts_raw |> String.downcase() |> String.split(",") do
    [ "hevc", preset, crf ] -> { :hevc, preset, crf }
    [ "hevc" ] -> { :hevc, "medium", 24 }
    _ -> raise "Unknown encoding options: #{inspect(encode_opts_raw)}"
  end

  config :mediamanage,
    encode_opts: encode_opts
end

if cachepath_raw = System.get_env("CACHEPATH") do
  # Trim to handle weird corner cases with environment variables on Linux I seem to be having
  if String.trim(cachepath_raw) != "" do
    full_path = Path.expand(cachepath_raw)

    # Just becuase you CAN have a cache named " " doesn't mean you SHOULD.
    if full_path |> Path.dirname() |> File.dir?() do
      config :mediamanage,
        cache_path: cachepath_raw
    else
      Logger.warning("CACHEPATH #{cachepath_raw} seems to be an invalid directory, falling back on default.")
    end

  else
    Logger.info("File caching disabled")
    config :mediamanage,
      cache_path: nil
  end

end

if listen_ip_raw = System.get_env("IP") do
  listen_ip = case listen_ip_raw do
    "any" -> :any
    "local" -> :loopback
    "loopback" -> :loopback
    _ -> case :inet.parse_address(to_charlist(listen_ip_raw)) do
      { :ok, ip } -> ip
      { :error, _ } -> raise "Couldn't parse IP (#{inspect(listen_ip_raw)})"
    end
  end

  config :mediamanage,
    listen_ip: listen_ip
end

if port_raw = System.get_env("PORT") do
  config :mediamanage,
    http_port: String.to_integer(port_raw)
end

# Any truthy value
if System.get_env("ASSUME_OK") do
  config :mediamanage,
    assume_ok: :true
end

if workdir_raw = System.get_env("WORKDIR") do
  workdir_full = Path.expand(workdir_raw)
  IO.puts("Workdir: #{workdir_full}")
  config :mediamanage,
    workdir: workdir_full
end


if log_level_raw = System.get_env("LOGLEVEL") do
  # I have no idea if this is necessary but I heard never to do String.to_atom() so...
  log_level = case String.downcase(log_level_raw) do
    "error" -> :error
    "warning" -> :warning
    "info" -> :info
    "debug" -> :debug
    #"trace" -> :trace
    _ -> raise "Unknown log level #{log_level_raw}, using :info"
  end

  config :logger,
    level: log_level
end
