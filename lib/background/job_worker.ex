import Background.JobQueue

defmodule Background.JobWorker do
  use Task

  def start_link({job_id, run_fn}) do
    Task.start_link(fn -> run(job_id, run_fn) end)
  end

  defp run(job_id, run_fn) do
    progress_callback = &(update_progress(job_id, &1))

    result = try do
      run_fn.(progress_callback)
    # Catches elixir / erlang stuff
    rescue exception ->
      { :error, { :exception, exception, __STACKTRACE__ } }
    # Catches all the other nonsense.
    catch kind, reason ->
      { :error, { :erlang, kind, reason } }
    end

    mark_complete(job_id, result)
  end
end
