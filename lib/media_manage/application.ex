defmodule MediaManage.Application do
  use Application

  def start(_type, _args) do
    log_config()

    children = [
      { Bandit, plug: MediaManage.Router, scheme: :http, port: 4000 },
      # TODO - Cache path from environment variable
      { StateManager, "out/cache" },
      { Background.JobSupervisor, nil },
      { Background.JobQueue, nil }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp log_config do
    require Logger

    Logger.info("=== Loaded Configuration ===
    Max Concurrency: #{inspect(Application.get_env(:mediamanage, :max_concurrency))}
    Encoding Preferences: #{inspect(Application.get_env(:mediamanage, :encode_settings))}
    Cache Path: #{inspect(Application.get_env(:mediamanage, :cache_path))}
    Log Level: #{inspect(Application.get_env(:logger, :level))}
    ================================")
  end
end
