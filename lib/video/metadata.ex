use FFmpex.Options

defmodule Video.Metadata do
  @behaviour Background.JobBehaviour

  defp file_changed?(path, existing_metadata) do
    file_modified = File.stat!(path, [{:time, :posix}]) |> Map.fetch!(:mtime)
    metadata_modified = get_in(existing_metadata, [path, :modified_time])

    # TODO - Use proper logging level
    #IO.puts("Testing file #{path}. File modified: #{file_modified}, metadata time: #{inspect(metadata_modified)}")

    case metadata_modified do
      nil -> :true
      ^file_modified -> :false
      _other_time -> :true
    end
  end

  @impl Background.JobBehaviour
  def prepare_as_job(path, options \\ %{}) do
    existing_metadata = Map.get(options, :existing, %{})

    run_fn = fn progress_callback ->
      path_metadata_guarded(path, existing_metadata, progress_callback)
    end

    cond do
      !is_binary(path) -> { :error, :path_not_binary }
      !File.dir?(path) -> { :error, :path_not_basedir }
      :true -> { :ok, run_fn }
    end
  end

  # Wrapper to allow calling from iEx and scripts without caring about progress update
  def path_metadata_smart(path, existing_metadata \\ %{}) do
    case prepare_as_job(path, %{ existing: existing_metadata }) do
      { :ok, run_fn } -> run_fn.(fn -> :nil end)
        IO.puts("I have no idea how you got here. Please report this")
        { :error, :unreachable }
      { :error, e } -> { :error, e }
    end
  end

  defp path_metadata_guarded(path, existing_metadata, progress_callback) do
    # TODO - Path.wildcard is very bad and slow, optimize
    media_files = Path.wildcard("#{path}/**") |> Enum.filter(&Video.video_file?/1)

    new_file_list = Enum.filter(media_files, &(file_changed?(&1, existing_metadata)))

    required_metadata_updates = length(new_file_list)

    # TODO - Use proper logging level
    #IO.puts("New/changed files")
    #IO.puts(FormatTools.format_pretty(new_file_list))

    new_changed_files = Enum.with_index(new_file_list) |> Enum.reduce(%{}, fn {target_path, idx}, metadata_map ->
      pct_done = trunc(idx / required_metadata_updates * 100)
      progress_callback.(pct_done)
      IO.puts("Getting metadata for #{target_path}")
      Map.put(metadata_map, target_path, Video.get_video_metadata(target_path))
    end)

    # TODO - I don't actually have to calculate this, can use \
    # Map.take instead of Map.drop but I'd like to have this diff available anyway for logging.
    deleted_files = Map.keys(existing_metadata) -- media_files
    # TODO - Use proper logging level
    #IO.puts("Deleted files")
    #IO.puts(FormatTools.format_pretty(deleted_files))

    new_metadata = existing_metadata |> Map.drop(deleted_files) |> Map.merge(new_changed_files)

    { :ok, new_metadata }
  end
end
