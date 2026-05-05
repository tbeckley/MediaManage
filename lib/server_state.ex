defmodule ServerState do
  use Agent

  def start_link(cache_path) do
    loaded_cache = case cache_path do
       [] -> []
       path -> Cache.load_cache(path)
    end

    Agent.start_link(fn -> loaded_cache end, name: __MODULE__)
  end

  @spec get_state() :: any()
  def get_state() do
    Agent.get(__MODULE__, & &1)
  end

  def set_state(new_state) do
    Agent.update(__MODULE__, fn _ -> new_state end)
  end

end
