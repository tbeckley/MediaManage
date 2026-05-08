import Background.JobQueue

defmodule Background.JobWorker do
  use Task

  def start_link(job) do
    Task.start_link(fn -> run(job) end)
  end

  defp run({ job_id, job_data }) do
    progress_callback = &(update_job_progress(job_id, &1))

    result = try do
       case job_data.type do
        :recode ->
          # TODO - Allow user to pick target re-encoding type
          Video.recode_file(job_data.path, job_data.encode_opts, progress_callback)
        :metadata ->
          metadata = get_in(StateManager.get_media(), [job_data.path, :media_files])
          Video.path_metadata_smart(job_data.path, metadata, progress_callback)
      end
    # Catches elixir / erlang stuff
    rescue exception ->
      { :error, { :exception, exception, __STACKTRACE__ } }
    # Catches all the other nonsense.
    catch kind, reason ->
      { :error, { kind, reason } }
    end

    mark_job_complete(job_id, result)
  end
end
