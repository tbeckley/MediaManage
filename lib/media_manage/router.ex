defmodule MediaManage.Router do
  use Plug.Router

  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug Plug.MethodOverride
  plug :match
  plug :dispatch

  get "/" do
    data = StateManager.get_media()

    path_data = data |> Map.to_list() |> Enum.map(fn {path, data} ->
      dt = case Map.get(data, :last_updated) do
        nil -> nil
        time -> System.system_time(:second) - time
      end

      %{
        path: path,
        modified_ago: Frontend.TimeAgo.ago(dt),
        able_refresh: is_nil(dt) or dt > 60
      }
    end)

    file_data = Map.values(data) |> Enum.flat_map(&Map.get(&1, :media_files))

    html = EEx.eval_file("templates/index.html.eex", path_data: path_data, file_data: file_data)
    send_resp(conn, :ok, html)
  end

  post "/watchpath" do
    %{ params: %{ "path" => path }} = conn
    StateManager.add_watch_path(path)
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  patch "/watchpath" do
    %{ params: %{ "path" => path }} = conn

    Background.JobQueue.queue_metadata_update(path)
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  delete "/watchpath" do
    %{ params: %{ "path" => path }} = conn
    StateManager.delete_watch_path(path)
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  patch "/recode" do
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
