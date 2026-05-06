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

  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug Plug.MethodOverride
  plug :match
  plug :dispatch

  get "/" do
    data = ServerState.get_state()

    path_data = data |> Map.to_list() |> Enum.map(fn {path, data} ->
      dt = case Map.get(data, :last_updated) do
        nil -> nil
        time -> System.system_time(:second) - time
      end

      %{
        path: path,
        modified_ago: TimeAgo.ago(dt),
        able_refresh: is_nil(dt) or dt > 60
      }
    end)

    file_data = Map.values(data) |> Enum.flat_map(&Map.get(&1, :media_files))

    #IO.inspect(file_data, [{:limit, :infinity}, {:pretty, :true }])

    html = EEx.eval_file("templates/index.html.eex", path_data: path_data, file_data: file_data)
    send_resp(conn, :ok, html)
  end

  post "/watchpath" do
    %{ params: %{ "path" => path }} = conn
    ServerState.get_state() |> Map.put_new(path, %{ last_updated: nil, media_files: [] }) |> ServerState.set_state()
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  delete "/watchpath" do
    %{ params: %{ "path" => path }} = conn
    ServerState.get_state() |> Map.delete(path) |> ServerState.set_state()
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  patch "/refresh" do
    %{ params: %{ "path" => path }} = conn

    VideoProperties.refresh_cache_path(path, ServerState.get_state() |> Map.get(path))
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  patch "/recode" do
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
