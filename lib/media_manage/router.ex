defmodule MediaManage.Router do
  use Plug.Router

  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug Plug.MethodOverride
  plug :match
  plug :dispatch

  get "/" do
    data = StateManager.get_media()

    system_time = System.system_time(:second)

    jobs = Background.JobQueue.get_jobs()

    running_jobs = Enum.map(jobs.running, fn { id, job } -> %{
      id: id,
      description: FormatTools.describe_job(job),
      duration: FormatTools.format_duration(system_time - job.start_ts),
      progress: job.progress
    } end)

    queued_jobs = Enum.map(jobs.queued,  fn { id, job } -> %{
      id: id,
      description: FormatTools.describe_job(job),
    } end)

    path_data = Map.to_list(data) |> Enum.map(fn {path, data} ->
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

    render_time = NaiveDateTime.local_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S")

    html = EEx.eval_file("templates/index.html.eex", [
      { :path_data, path_data },
      { :file_data, file_data },
      { :job_data, %{ running: running_jobs, queued: queued_jobs } },
      { :page_render_time, render_time }
    ])
    send_resp(conn, :ok, html)
  end

  post "/watchpath" do
    # TODO - Make sure it's not a subpath or superpath of an existing path...
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
    %{ params: %{ "path" => path }} = conn

    # TODO - Get these from frontend somehow, or state at least
    # TODO - Change
    encode_opts = { :hevc, "faster", 24 }

    Background.JobQueue.queue_recode_file(path, encode_opts)
    conn |> put_resp_header("location", "/") |> send_resp(302, "")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
