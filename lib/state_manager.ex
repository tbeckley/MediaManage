defmodule StateManager do
  require Logger

  use GenServer

  def start_link(cache_path) do
    GenServer.start_link(__MODULE__, cache_path, name: __MODULE__)
  end

  # Media Metadata
  def get_media() do
    GenServer.call(__MODULE__, :get_media)
  end

  def set_path_metadata(path, metadata) do
    GenServer.cast(__MODULE__, { :set_metadata, path, metadata })
  end

  def report_reencoded(old_path, new_state_map) do
    GenServer.cast(__MODULE__, { :reencoded, old_path, new_state_map })
  end

  def add_watch_path(path) do
    GenServer.cast(__MODULE__, { :add_path, path})
  end

  def delete_watch_path(path) do
    GenServer.cast(__MODULE__, { :delete_path, path})
  end

  def debug_metadata(path \\ "out/debug.txt") do
    GenServer.cast(__MODULE__, {:debug_state, path})
  end

  # Private Helpers
  defp schedule_persist() do
    write_interval = Application.get_env(:mediamanage, :cache_interval)
    Process.send_after(self(), :persist, write_interval)
  end

  defp persist_to_disk(state) do
    cache_path = Application.get_env(:mediamanage, :cache_path)
    Cache.save_cache(state, cache_path)
  end

  # Callbacks
  @impl true
  def init(cache_path) do
    media_cache = Cache.load_cache(cache_path)
    schedule_persist()
    { :ok, media_cache }
  end

  @impl true
  def handle_cast({ :add_path, path }, state) do
    { :noreply, Map.put_new(state, path, %{ last_updated: nil, media_files: %{} }) }
  end

  @impl true
  def handle_cast({ :delete_path, path }, state) do
    { :noreply, Map.delete(state, path) }
  end

  # Update the metadata at path to new_metadata
  @impl true
  def handle_cast({ :set_metadata, path, new_metadata }, state) do
    new_state = Map.put(state, path, %{
      last_updated: System.system_time(:second),
      media_files: new_metadata
    })

    { :noreply, new_state }
  end

  # Report that a file has been transcoded.
  @impl true
  def handle_cast({ :reencoded, old_path, new_map }, state) do
    # We need to find out which base path this belongs to before we can update it
    base_path = Map.keys(state) |> Enum.find(&String.contains?(old_path, &1))

    [{ new_path, _new_metadata }] = Map.to_list(new_map)
    Logger.debug("New metadata received for #{new_path} (base path: #{base_path})")

    if is_nil(base_path) do
      Logger.error("Couldn't find a base path for #{old_path}")
      { :noreply, state }
    else
      new_state = update_in(state, [base_path, :media_files], fn old_media ->
        Map.delete(old_media, old_path) |> Map.merge(new_map) end)
      { :noreply, new_state }
    end
  end

  # Get media
  @impl true
  def handle_call(:get_media, _from, state) do
    { :reply,  state, state }
  end

  # Debug state
  @impl true
  def handle_call({ :debug_state, file_path }, _from, state) do
    File.write!(file_path, FormatTools.format_pretty(state))
    { :noreply, state }
  end

  # Persist state to disk
  @impl true
  def handle_info(:persist, state) do
    persist_to_disk(state)
    { :noreply, state }
  end

  @impl true
  def terminate(_reason, state) do
    IO.puts("Terminate")
    Logger.warning("Terminating")
    File.write("out/terminate", "hello")
    persist_to_disk(state)
  end
end
