defmodule StateManager do
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

  def add_watch_path(path) do
    GenServer.cast(__MODULE__, { :add_path, path})
  end

  def delete_watch_path(path) do
    GenServer.cast(__MODULE__, { :delete_path, path})
  end

  def debug_metadata(path \\ "out/debug.txt") do
    GenServer.cast(__MODULE__, {:debug_state, path})
  end

  # Callbacks
  @impl true
  def init(cache_path \\ "") do
    media_cache = Cache.load_cache(cache_path)
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

  # Get media
  @impl true
  def handle_call(:get_media, _from, state) do
    { :reply,  state, state }
  end

  # Debug state
  @impl true
  def handle_call({ :debug_state, file_path }, _from, state) do
    File.write!(file_path, inspect(state, [{ :pretty, :true}, { :limit, :infinity }]))
    { :noreply, state }
  end
end
