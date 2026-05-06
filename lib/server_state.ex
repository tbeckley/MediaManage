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
    IO.puts("Updating state");
    Agent.update(__MODULE__, fn _ -> new_state end)
  end

  def get_state_string() do
    inspect(get_state(), [{:limit, :infinity}, {:pretty, :true}])
  end

  def debug_to_file() do
    debug_to_file("out/debug.txt")
  end

  def debug_to_file(path) do
    File.write!(path,  get_state_string())
  end
end
