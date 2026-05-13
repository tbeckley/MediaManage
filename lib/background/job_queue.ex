defmodule Background.JobQueue do
  require Logger
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
    GenServer.cast(__MODULE__, { :progress, job_id, progress })
  end

  def register_cleanup(job_id, cleanup_fn) do
    GenServer.cast(__MODULE__, { :set_cleanup, job_id, cleanup_fn })
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

  # Private Helpers

  defp graceful_kill_all_tasks(running) do
    running |> Map.to_list() |> Enum.each(fn { job_id, job_data } ->
      Logger.info("Killing job #{job_id}")
      Map.get(job_data, :pid) |> Process.exit(:kill)

      if cleanup_fn = Map.get(job_data, :cleanup_fn) do
        Logger.debug("Running cleanup function!")
        cleanup_fn.()
      end
    end)
  end

  # Callbacks

  @impl true
  def init(_options) do
    default_state = %{
      next_job_id: 0,
      queued: %{},
      running: %{},
      failed: %{},
      max_concurrency: Application.get_env(:mediamanage, :max_concurrency)
    }

    {:ok, default_state }
  end

  @impl true
  def handle_cast({ :enqueue, new_job }, state) do
    %{ queued: queued, running: running, next_job_id: next_job_id } = state

    all_jobs = Map.values(running) ++  Map.values(queued)

    # We can't match on the map ittself, sadly. This is a corner case with match?/2
    # https://hexdocs.pm/elixir/Kernel.html#match?/2-values-vs-patterns

    %{ type: type, path: path } = new_job

    if Enum.any?(all_jobs, &match?(%{ type: ^type, path: ^path }, &1)) do
      Logger.info("Job already exists, not adding.")
      { :noreply, state }
    else
      send(self(), :run_next)

      { :noreply, %{
        put_in(state, [:queued, next_job_id], new_job) |
        next_job_id: next_job_id + 1
      }}
    end
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
    Logger.info("Clearing failed jobs!")
    { :noreply, %{ state | failed: %{} } }
  end

  @impl true
  def handle_cast({ :set_cleanup, job_id, cleanup_fn }, state) do
    new_state = put_in(state, [:running, job_id, :cleanup_fn], cleanup_fn)
    { :noreply, new_state }
  end

  @impl true
  def handle_cast({ :progress, job_id, progress}, state) do
    { :noreply, put_in(state, [:running, job_id, :progress], progress) }
  end

  @impl true
  def handle_cast({ :complete, job_id, { :ok, data }}, state) do
    Logger.info("Job #{job_id} completed!")
    job_spec = get_in(state, [:running, job_id])

    case Map.get(job_spec, :type) do
      :recode -> StateManager.report_reencoded(job_spec.path, data)
      :metadata -> StateManager.set_path_metadata(job_spec.path, data)
      # These two should never run
      nil -> IO.inspect("Somehow managed to finish a non-existing job?!")
      other_key -> IO.inspect("Finished uncontrolled job #{inspect(other_key)}")
    end

    send(self(), :run_next)
    { :noreply, %{ state | running: Map.delete(state.running, job_id)}}
  end

  @impl true
  def handle_cast({ :complete, job_id, { :error, error_data }}, state) do
    Logger.info("Job #{job_id} failed!")
    job_spec = get_in(state, [:running, job_id])

    failed_spec = Map.delete(job_spec, :pid) |> Map.merge(%{
      fail_ts: System.system_time(:second),
      error_data: error_data
    })

    new_failed = Map.put_new(state.failed, job_id, failed_spec)
    new_running = Map.delete(state.running, job_id)

    send(self(), :run_next)
    { :noreply, %{ state | failed: new_failed, running: new_running } }
  end

  @impl true
  def handle_cast({ :kill, job_id }, state) do
    case get_in(state, [:running, job_id, :pid]) do
      nil ->
        Logger.warning("Job #{job_id} is not running!")
        { :noreply, state }
      pid when is_pid(pid) ->
        Logger.info("Killing job #{job_id}")
        Process.exit(pid, :kill)

        with cleanup when is_function(cleanup) <- get_in(state, [:running, job_id, :cleanup_fn]) do
          Logger.debug("Running cleanup function")
          cleanup.()
        end

        new_running = Map.delete(state.running, job_id)
        # We've created an opening that won't otherwise be filled
        send(self(), :run_next)
        { :noreply, %{ state | running: new_running } }
    end
  end

  @impl true
  def handle_cast(:kill_all, state) do
    graceful_kill_all_tasks(state.running)

    # Start up new items if things are queued
    send(self(), :run_next)
    { :noreply, %{ state | running: %{} }}
  end

  @impl true
  def handle_call(:get_jobs, _from, state) do
    { :reply, state, state }
  end

  @impl true
  def handle_info(:run_next, state) do
    %{ queued: queued, running: running } = state
    max_concurrency = Application.get_env(:mediamanage, :max_concurrency)

    if map_size(running) < max_concurrency and map_size(queued) > 0 do
      job_id = Map.keys(queued) |> Enum.min()
      { job_data, others } = Map.pop(queued, job_id)

      # I just realized this is infallable, and if it fails we wanna end the whole process anyway
      Logger.info("Running job #{job_id}")
      { :ok, pid } = DynamicSupervisor.start_child(Background.JobSupervisor, { Background.JobWorker, { job_id, job_data } })

      new_job_data = Map.merge(job_data, %{ progress: 0, pid: pid, start_ts: System.system_time(:second) })

      # I could check this I guess but I'm worried about all sorts of race condition corner cases
      # So I'm just going to send it recursive-style (it's idiomatic!)
      send(self(), :run_next)

      { :noreply, %{
        state |
        queued: others,
        running: Map.put(running, job_id, new_job_data) }
      }
    else
      { :noreply, state }
    end
  end

  @impl true
  def terminate(_reason, state) do
    graceful_kill_all_tasks(state.running)
  end
end
