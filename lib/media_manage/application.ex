defmodule MediaManage.Application do
  use Application

  def start(_type, _args) do
    children = [
      { Bandit, plug: MediaManage.Router, scheme: :http, port: 4000 },
      # TODO - Cache path from environment variable
      { StateManager, "out/cache" },
      { Background.JobSupervisor, nil },
      { Background.JobQueue, nil }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
