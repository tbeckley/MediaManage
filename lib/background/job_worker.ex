import Background.JobQueue

defmodule Background.JobWorker do
  use Task

  def start_link(job) do
    Task.start_link(fn -> run(job) end)
  end

  defp run({ job_id, job_data }) do
    job_functions = %{
      progress: &(update_progress(job_id, &1)),
      cleanup: &(register_cleanup(job_id, &1))
    }

    result = try do
       case job_data.type do
        :recode ->
          # TODO - Allow user to pick target re-encoding type
          Video.recode_file(job_data.path, job_data.encode_opts, job_functions)
        :metadata ->
          metadata = get_in(StateManager.get_media(), [job_data.path, :media_files])
          Video.path_metadata_smart(job_data.path, metadata, job_functions)
      end
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
