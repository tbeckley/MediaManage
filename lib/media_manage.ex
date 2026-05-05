defmodule MediaManage do
 @moduledoc """
 Placeholder
 """
end

defmodule MediaManage.Application do
  use Application

  def start(_type, _args) do
    IO.puts("Starting app custom message!");
    children = [
      { Bandit, plug: MediaManage.Router, scheme: :http, port: 4000 },
      { ServerState, "out/cache" }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

end

defmodule MediaManage.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    data = ServerState.get_state()

    path_data = Enum.map(data, fn p ->
      case Map.get(p, :last_updated) do
        nil -> %{ path: p.path,
          modified_ago: "never",
          refresh_eligible: :true
        }
        cache_last_updated -> cache_age = System.system_time(:second) - cache_last_updated
        %{
          path: p.path,
          modified_ago: TimeAgo.ago(cache_age),
          refresh_eligible: cache_age > 60 * 60
        }
      end
    end);

    file_data = Enum.flat_map(data, &Map.get(&1, :media_files))

    # str_data = inspect(data, [{:limit, :infinity}, {:pretty, :true}]

    html = EEx.eval_file("templates/index.html.eex", path_data: path_data, file_data: file_data)
    send_resp(conn, 200, html)
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
