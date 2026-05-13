defmodule MediaManage.Application do
  use Application

  def start(_type, _args) do
    log_config()

    http_port = Application.get_env(:mediamanage, :http_port)
    listen_ip = Application.get_env(:mediamanage, :listen_ip)

    children = [
      { Bandit, plug: MediaManage.Router, scheme: :http, port: http_port, ip: listen_ip },
      # TODO - Cache path from environment variable
      { StateManager, "out/cache" },
      { Background.JobSupervisor, nil },
      { Background.JobQueue, nil }
    ]

    # Shouldn't take 5s to write out state and clean everything up...
    Supervisor.start_link(children, [
      { :strategy, :one_for_one} ,
      { :shutdown, 5_000 },
      { :name, MediaManage.Supervisor }
    ])
  end

  def stop() do
    Application.stop(:mediamanage)
  end

  def log_config() do
    require Logger

    env_info = Application.get_all_env(:mediamanage)
    log_level = Application.get_env(:logger, :level)

    # Special case log level for now
    config_vals = env_info |> Enum.map(fn { key, val } ->
      "#{FormatTools.pretty_atom(key)}: #{inspect(val)}" end) |> Enum.join("\n")

    # Yes, I had to do this. Sad.
    Logger.info(String.trim("""
    =======MediaManage Config======
    #{config_vals}
    Log Level: #{log_level}
    ===============================
    """))

  end
end
