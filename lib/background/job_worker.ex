import Background.JobQueue

defmodule Background.JobWorker do
  use Task

  def start_link(job) do
    Task.start_link(fn -> run(job) end)
  end

  defp run({ job_id, job_data }) do
    IO.puts("Running job ##{inspect(job_id)} in background")

    result = case job_data.type do
      :recode -> VideoProperties.recode_file(job_data.path, "h265", &(update_job_progress(job_id, &1)))
      :metadata -> VideoProperties.path_metadata_smart(job_data.path, Map.get(StateManager.get_media(), job_data.path))
    end

    mark_job_complete(job_id, result)
  end
end
