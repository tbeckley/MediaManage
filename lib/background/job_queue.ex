defmodule Background.JobQueue do
  use GenServer

  # Public API

  def start_link(_options) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def queue_recode_file(file_path) do
    GenServer.cast(__MODULE__, {:enqueue, %{type: :recode, path: file_path}})
  end

  def queue_metadata_update(dir_path) do
    GenServer.cast(__MODULE__, {:enqueue, %{type: :metadata, path: dir_path}})
  end

  def clear_queue() do
    GenServer.cast(__MODULE__, :clear_queue)
  end

  def get_jobs() do
    GenServer.call(__MODULE__, :get_jobs)
  end

  def update_job_progress(job_id, progress) do
    IO.puts("Job #{job_id} is #{progress}% done!")
  end

  def mark_job_complete(job_id, result) do
    GenServer.cast(__MODULE__, { :complete, job_id, result })
  end

  # Callbacks

  @impl true
  def init(_options) do
    default_state = %{
      next_job_id: 0,
      queued: %{},
      running: %{},
      failed: %{}
    }

    {:ok, default_state }
  end

  @impl true
  def handle_cast({:enqueue, new_job}, state) do
    %{ next_job_id: next_job_id } = state
    new_state = %{
      put_in(state, [:queued, next_job_id], new_job) |
      next_job_id: next_job_id + 1
    }

    if state.queued == %{} do
      send(self(), :run_next)
    end

    { :noreply, new_state }
  end

  @impl true
  def handle_cast(:clear_queue, state) do
    { :noreply, %{ state | queued: %{} } }
  end

  @impl true
  def handle_cast({ :complete, job_id, result}, state) do
    IO.puts("Recieved job #{job_id} complete")
    job_spec = get_in(state, [:running, job_id])

    new_state = case result do
      {:ok, _data} -> case Map.get(job_spec, :type) do
          # TODO - Handle successfully completed recode
          :recode -> IO.inspect("Successfully completed recode")
          # TODO - Handle successfully completed metadata
          :metadata -> IO.inspect("Successfully completed metadata")
          # These two should never run
          nil -> IO.inspect("Somehow managed to finish a non-existing job?!")
          other_key -> IO.inspect("Finished uncontrolled job #{inspect(other_key)}")
        end
        state
      # TODO - Handle failed tasks
      {:error, reason } ->
        IO.inspect("Uh oh! Failed task! #{inspect(reason)}")
        %{ state | failed: Map.put_new(state.failed, job_id, job_spec)}
    end

    { :noreply, %{ new_state | running: Map.delete(state.running, job_id)}}
  end

  @impl true
  def handle_call(:get_jobs, _from, state) do
    { :reply, state, state }
  end

  @impl true
  def handle_info(:run_next, state) do
    %{ queued: queued, running: running, failed: failed } = state
    job_id = Map.keys(queued) |> Enum.min()
    { job_data, others } = Map.pop(queued, job_id)

    start_result = DynamicSupervisor.start_child(Background.JobSupervisor, { Background.JobWorker, { job_id, job_data } })

    intermediate_state = case start_result do
      { :ok, _pid } ->
        new_running = Map.put(running, job_id, Map.put_new(job_data, :progress, 0))
        %{ state | running: new_running }
      { :error, reason } ->
        new_failed = Map.put(failed, job_id, Map.put_new(job_data, :error, reason))
        %{ state | failed: new_failed}
    end

    # Requeue if there's still jobs to do
    # TODO - Add limit so I'm not running 124812471 jobs at once
    if others != %{} do
      send(self(), :run_next)
    end

    { :noreply, %{ intermediate_state | queued: others } }
  end
end
