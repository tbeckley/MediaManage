defmodule Cache do
  require Logger

  def load_cache(cache_path) do
    case File.read(cache_path) do
      {:ok, cache_data} -> :erlang.binary_to_term(cache_data)
      {:error , :enoent} ->
        Logger.info("Couldn't find cache file. Starting fresh.")
        %{}
      {:error, :eisdir} -> raise "Given cache file path is a directory!"
      {:error, error_type} -> raise "Some other error loading the cache file: #{:file.format_error(error_type)}"
    end
  end

  # TODO - Actually call this...
  def save_cache(cache, cache_path) do
    bin_data = :erlang.term_to_binary(cache, [:compressed, :deterministic])
    case File.write(cache_path, bin_data) do
      :ok -> Logger.info("Wrote out cache to #{cache_path}")
      {:error, err_type} when err_type in [:enoent, :enotdir] -> Logger.warning("Couldn't write cache file. Possbily bad path?")
      {:error, err_type} -> Logger.warning("Couldn't write cache file: #{:file.format_error(err_type)}")
    end
    nil
  end

end
