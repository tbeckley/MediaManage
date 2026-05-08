defmodule Background.JobQueue do
  use GenServer



  # Public API
  def start_link(_options) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def queue_recode_file(file_path, encode_opts) do
    GenServer.cast(__MODULE__, {:enqueue, %{type: :recode,
      path: file_path, encode_opts: encode_opts}})
  end

  def queue_metadata_update(dir_path) do
    GenServer.cast(__MODULE__, {:enqueue, %{type: :metadata, path: dir_path}})
  end

  def clear_queue() do
    GenServer.cast(__MODULE__, :clear_queue)
  end

  def clear_failed() do
    GenServer.cast(__MODULE__, :clear_failed)
  end

  def get_jobs() do
    GenServer.call(__MODULE__, :get_jobs)
  end

  def update_job_progress(job_id, progress) do
    GenServer.cast(__MODULE__, { :progress, job_id, progress})
  end

  def mark_job_complete(job_id, result) do
    GenServer.cast(__MODULE__, { :complete, job_id, result })
  end

  def kill_job(job_id) do
    GenServer.cast(__MODULE__, { :kill, job_id })
  end

  def kill_all_jobs() do
    GenServer.cast(__MODULE__, :kill_all)
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
  def handle_cast(:clear_failed, state) do
    { :noreply, %{ state | failed: %{} } }
  end

  @impl true
  def handle_cast({ :progress, job_id, progress}, state) do
    { :noreply, put_in(state, [:running, job_id, :progress], progress) }
  end

  @impl true
  def handle_cast({ :complete, job_id, { :ok, data }}, state) do
    job_spec = get_in(state, [:running, job_id])

    case Map.get(job_spec, :type) do
      # TODO - Handle successfully completed recode
      :recode -> IO.puts("Recode successfully finished!")
      :metadata -> StateManager.set_path_metadata(job_spec.path, data)
      # These two should never run
      nil -> IO.inspect("Somehow managed to finish a non-existing job?!")
      other_key -> IO.inspect("Finished uncontrolled job #{inspect(other_key)}")
    end

    { :noreply, %{ state | running: Map.delete(state.running, job_id)}}
  end

  @impl true
  def handle_cast({ :complete, job_id, { :error, error_data }}, state) do
    IO.inspect("Uh oh! Failed task #{job_id}! (#{inspect(error_data)})")

    job_spec = get_in(state, [:running, job_id])

    failed_spec = Map.delete(job_spec, :pid) |> Map.merge(%{
      fail_ts: System.system_time(:second),
      error_data: error_data
    })

    new_failed = Map.put_new(state.failed, job_id, failed_spec)
    new_running = Map.delete(state.running, job_id)

    { :noreply, %{ state | failed: new_failed, running: new_running } }
  end

  @impl true
  def handle_cast({ :kill, job_id }, state) do
    case get_in(state, [:running, job_id, :pid]) do
      nil ->
        IO.puts("Job #{job_id} is not running!")
        { :noreply, state }
      pid when is_pid(pid) ->
        Process.exit(pid, :kill)
        new_running = Map.delete(state.running, job_id)
        { :noreply, %{ state | running: new_running } }
    end
  end

  @impl true
  def handle_cast(:kill_all, state) do
    state.running |> Map.values() |> Enum.map(&(Map.get(&1, :pid))) |> Enum.each(&(Process.exit(&1, :kill)))
    { :noreply, %{ state | running: %{} }}
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
      { :ok, pid } ->
        new_job_data = Map.merge(job_data, %{ progress: 0, pid: pid, start_ts: System.system_time(:second) })
        %{ state | running: Map.put(running, job_id, new_job_data) }
      { :error, reason } ->
        new_job_data = Map.merge(job_data, %{ start_ts: System.system_time(:second), error: reason })
        %{ state | failed: Map.put(failed, job_id, new_job_data) }
    end

    # Requeue if there's still jobs to do
    # TODO - Add limit so I'm not running 124812471 jobs at once
    if others != %{} do
      send(self(), :run_next)
    end

    { :noreply, %{ intermediate_state | queued: others } }
  end
end
