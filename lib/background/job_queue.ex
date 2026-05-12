defmodule Background.JobQueue do
  use GenServer

  # Public API
  def start_link(_options) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def queue_recode_file(file_path, encode_params) do
    GenServer.cast(__MODULE__, {:enqueue, %{
      type: :recode,
      path: file_path,
      opts: %{
        encode_params: encode_params
    }}})
  end

  def queue_metadata_update(dir_path) do
    metadata = get_in(StateManager.get_media(), [dir_path, :media_files])

    GenServer.cast(__MODULE__, {:enqueue, %{
      type: :metadata,
      path: dir_path,
      opts: %{
        existing: metadata
    }}})
  end

  def cancel_queued(job_id) do
    GenServer.cast(__MODULE__, { :cancel, job_id } )
  end

  def clear_queue() do
    GenServer.cast(__MODULE__, :clear_queue)
  end

  def clear_failed(job_id) do
    GenServer.cast(__MODULE__, { :clear_failed, job_id })
  end

  def clear_all_failed() do
    GenServer.cast(__MODULE__, :clear_failed)
  end

  def get_jobs() do
    GenServer.call(__MODULE__, :get_jobs)
  end

  def update_progress(job_id, progress) do
    GenServer.cast(__MODULE__, { :progress, job_id, progress})
  end

  def mark_complete(job_id, result) do
    GenServer.cast(__MODULE__, { :complete, job_id, result })
  end

  def kill(job_id) do
    GenServer.cast(__MODULE__, { :kill, job_id })
  end

  def kill_all() do
    GenServer.cast(__MODULE__, :kill_all)
  end

  # Callbacks

  @impl true
  def init(_options) do
    default_state = %{
      next_job_id: 0,
      queued: %{},
      running: %{},
      failed: %{},
      max_concurrency: :infinity
    }

    {:ok, default_state }
  end

  @impl true
  def handle_cast({ :enqueue, new_job }, state) do
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

  def handle_cast({ :cancel, job_id }, state) do
    { :noreply, %{ state | queued: Map.delete(state.queued, job_id) } }

  end

  @impl true
  def handle_cast(:clear_queue, state) do
    { :noreply, %{ state | queued: %{} } }
  end

  @impl true
  def handle_cast({ :clear_failed, job_id }, state) do
    { :noreply, %{ state | failed: Map.delete(state.failed, job_id) } }
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
      :recode -> StateManager.report_reencoded(job_spec.path, data)
      :metadata -> StateManager.set_path_metadata(job_spec.path, data)
      # These two should never run
      nil -> IO.inspect("Somehow managed to finish a non-existing job?!")
      other_key -> IO.inspect("Finished uncontrolled job #{inspect(other_key)}")
    end

    { :noreply, %{ state | running: Map.delete(state.running, job_id)}}
  end

  @impl true
  def handle_cast({ :complete, job_id, { :error, error_data }}, state) do
    job_spec = get_in(state, [:running, job_id])

    new_failed = Map.put_new(state.failed, job_id, gen_failed_entry(job_spec, error_data))
    new_running = Map.delete(state.running, job_id)

    { :noreply, %{ state | failed: new_failed, running: new_running } }
  end

  @impl true
  def handle_cast({ :kill, job_id }, state) do
    job_data = Map.get(state.running, job_id)
    case Map.get(job_data, :pid) do
      nil ->
        IO.puts("Job #{job_id} is not running!")
        IO.inspect(Map.get(state.running, 0))
        { :noreply, state }
      pid when is_pid(pid) ->
        Process.exit(pid, :kill)

        case Map.get(job_data, :cleanup_fn) do
          nil ->
            IO.puts("No cleanup needed after #{job_id}")
          # TODO - Should swallow or handle (better) errors
          cleanup_fn when is_function(cleanup_fn) ->
            IO.puts("Cleaning up after job #{job_id}")
            cleanup_fn.()
          cleanup_fn ->
            IO.puts("Somehow managed to get a cleanup \
              function that wasn't a function or nil! #{inspect(cleanup_fn)}. Please report this!")
        end

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
    job_id = Map.keys(state.queued) |> Enum.min()
    { job_data, others } = Map.pop(state.queued, job_id)

    new_state = case prepare_job(job_data) do
      { :error, error_reason } ->
        failed_entry = gen_failed_entry(job_data, error_reason)
        put_in(state, [:failed, job_id], failed_entry)
      { :ok, run_fn, cleanup_fn } ->
        running_entry = Map.merge(job_data, %{
          start_ts: System.system_time(:second),
          progress: 0,
          pid: start_worker(job_id, run_fn),
          cleanup_fn: cleanup_fn
        })
        put_in(state, [:running, job_id], running_entry)
    end

    # Requeue if there's still jobs to do
    # TODO - Add limit so I'm not running 124812471 jobs at once
    if others != %{} do
      send(self(), :run_next)
    end

    { :noreply, %{ new_state | queued: others } }
  end

  # Private Helpers

  defp gen_failed_entry(job_spec, fail_reason) do
    job_spec |> Map.drop([:pid, :cleanup_fn, :progress]) |> Map.merge(%{
      fail_ts: System.system_time(:second),
      error_data: fail_reason
    })
  end


  defp start_worker(job_id, run_fn) do
    { :ok, pid } = DynamicSupervisor.start_child(
      Background.JobSupervisor,{
      Background.JobWorker, { job_id, run_fn }
    })

    pid
  end

  defp prepare_job(job_data) do
    job_mod = Video.module_for(job_data.type)
    job_opts = Map.get(job_data, :opts, %{})

    # TODO - Convert the job opts better I think
    case job_mod.prepare_as_job(job_data.path, job_opts) do
      { :error, reason } -> { :error, reason }
      { :ok, run_fn } -> { :ok, run_fn, nil }
      { :ok, run_fn, cleanup_fn } -> { :ok, run_fn, cleanup_fn }
    end
  end
end
