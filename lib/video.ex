import FFmpex
use FFmpex.Options

defmodule Video do
  require Logger
  # List of supported media file extensions. Maybe this should change...
  @file_extension ["m4v", "mp4", "mkv", "webm", "avi"]

  @global_ffmpeg_encode_opts [
    option_v("error"),
    option_n(),
    option_progress("pipe:1"),
    option_xerror()
  ]

  def video_file?(video_path) do
    !File.dir?(video_path) and String.ends_with?(Path.extname(video_path), @file_extension)
  end

  defp broken?(video_path) do
    ffmpeg_cmd = FFmpex.new_command() |> FFmpex.add_input_file(video_path)
      |> FFmpex.to_stdout() |> FFmpex.add_file_option(option_f("null"))
      |> FFmpex.add_global_option(option_xerror()) |> FFmpex.add_global_option(option_v("error"))

    case FFmpex.execute(ffmpeg_cmd) do
      {:ok, _} -> :false
      {:error, _} -> :true
    end
  end

  def get_video_metadata(video_path, opts \\ []) do
    assume_ok = :assume_ok in opts

    Logger.debug("Getting metadata for #{video_path}")
    {:ok, %{:size => file_size, :mtime => modified_time }} = File.stat(video_path, [{:time, :posix}])

    case FFprobe.streams(video_path) do
      {:ok, streams} ->
        video_stream = Enum.find(streams, &(&1["codec_type"] == "video"))
        duration = FFprobe.duration(video_path);

        broken = case assume_ok do
          :true -> :false
          :false -> broken?(video_path)
        end

        %{
          :broken => broken,
          :modified_time => modified_time,
          :video_codec => Map.get(video_stream, "codec_name"),
          :duration => trunc(duration),
          :bps => trunc(file_size/duration)
        };
      {:error, :invalid_file} ->
        %{
          :broken => :true,
          :modified_time => modified_time
        }
    end
  end

  # I don't feel great about this. I _ALMOST_ feel that the new path should come from higher up the chain
  # So we're not just blindly trusting that the recode_file() function works properly
  defp get_recode_paths(input_path, codec, workdir \\ :nil) do
    { encode_supersuffix, output_extension } = case codec do
      :hevc -> { ".x265", ".mp4" }
      :mp4 -> { ".x264", ".mp4" }
      :av1 -> { ".av1", ".av1" }
    end

    workpath = workdir || Path.dirname(input_path)

    workfile = Path.join(workpath, Path.basename(input_path) <> encode_supersuffix)
    final_file = Path.rootname(input_path) <> output_extension

    { workfile, final_file }
  end

  def recode_file(video_path, encoding_options, job_functions \\ %{}) do
    update_progress = Map.get(job_functions, :progress, :false)
    register_cleanup = Map.get(job_functions, :cleanup)

    target_codec = elem(encoding_options, 0)
    %{ duration: duration } = Video.get_video_metadata(video_path, [:assume_ok])

    # TODO - Allow different temp directory for encoding into and copying
    { work_path, out_path } = get_recode_paths(video_path, target_codec)

    cleanup_fn = fn -> File.rm(work_path) end
    progress_fn = with c when is_function(c) <- update_progress do
      fn chunk -> with t when not is_nil(t) <- FFmpegHelper.time_from_chunk(chunk) do
          c.(min(100, trunc(t * 100 / duration)))
        end
      end
    end

    cond do
      !File.exists?(video_path) -> { :error, :enoent }
      File.exists?(work_path) -> { :error, :workfile_exists }
      File.exists?(out_path) and out_path != video_path -> { :error, :outfile_exists }
      :true ->
        if is_function(register_cleanup) do
            register_cleanup.(cleanup_fn)
        end

        ffmpeg_result = recode_file_guarded(video_path, work_path, encoding_options, progress_fn)

        case ffmpeg_result do
          { :ok, _ } ->
            # Delete the old file
            File.rm(video_path)
            # I asked copilot for a review and it said there's a race condition here. I think that's wrong.
            # Rename should just pave over the top anyway. At least it should on *nix. Unsure about Windows.
            File.rename(work_path, out_path)
            new_metadata = get_video_metadata(out_path, [:assume_ok])
            { :ok, %{ out_path => new_metadata } }
          { :error, reason } ->
            # Cleanup on a failed recode for some reason
            cleanup_fn.()
            { :error, reason }
        end
    end
  end

  defp recode_file_guarded(in_path, out_path, encoding_options, handle_log) do
    Logger.info("Re-encoding #{in_path} to #{out_path}")
    file_opts = FFmpegHelper.ffmpeg_opts_from_encoding(encoding_options)

    base_cmd = FFmpex.new_command() |> add_input_file(in_path) |> add_output_file(out_path)
    with_global_opts = Enum.reduce(@global_ffmpeg_encode_opts, base_cmd, fn opt, acc -> add_global_option(acc, opt) end)
    full_cmd = Enum.reduce(file_opts, with_global_opts, fn opt, acc -> add_file_option(acc, opt) end)

    { bin, opts } = FFmpex.prepare(full_cmd)
    # FFmpex doesn't have a option_stats_period() and I don't want to add one :(
    # We have to run anyway via Rambo so we'll just cheat :)
    full_opts = ["-stats_period", "5"] ++ opts

    full_cmd = Enum.join([bin | full_opts], " ")
    Logger.debug("Full command: #{full_cmd}")

    ffmpeg_result = Rambo.run(bin, full_opts, [{ :log, handle_log }])

    case ffmpeg_result do
      { :error, %Rambo{ out: _out_msg, err: err_msg } } -> { :error, { :ffmpeg, err_msg } }
      { :error, e } -> { :error, { :ffmpeg, e }}
      { :ok, %Rambo{ status: status_code, err: stderr } } when status_code != 0 -> { :error, { :ffmpeg, stderr }}
      { :ok, %Rambo{ status: 0, err: stderr, out: stdout } } ->
        if FFmpegHelper.errmsg_is_error(stderr) do
          { :error, { :ffmpeg, stderr }}
        else
          { :ok, stdout }
        end
    end
  end

  defp file_changed?(path, existing_metadata) do
    file_modified = File.stat!(path, [{:time, :posix}]) |> Map.fetch!(:mtime)
    metadata_modified = get_in(existing_metadata, [path, :modified_time])

    Logger.debug("Testing file #{path}. File modified: #{file_modified}, metadata time: #{inspect(metadata_modified)}")

    case metadata_modified do
      nil -> :true
      ^file_modified -> :false
      _other_time -> :true
    end
  end

  # Wrapper to allow calling from iEx and scripts without caring about progress update
  def path_metadata_smart(path, existing_metadata \\ %{}) do
    path_metadata_smart(path, existing_metadata, %{})
  end

  # If existing_metadata is supplied, only get video metadata for files that need it
  def path_metadata_smart(path, existing_metadata, job_functions)  do
    cond do
      !is_binary(path) -> { :error, :path_not_binary }
      !File.dir?(path) -> { :error, :path_not_basedir }
      :true -> path_metadata_guarded(path, existing_metadata, job_functions)
    end
  end

  defp path_metadata_guarded(path, existing_metadata, job_functions) do
    Logger.info("Updating metadata for #{path}")

    # Find out if we have a progress callback function available
    progress_callback = Map.get(job_functions, :progress)

    # TODO - Path.wildcard is very bad and slow, optimize
    media_files = Path.wildcard("#{path}/**") |> Enum.filter(&video_file?/1)
    new_file_list = Enum.filter(media_files, &(file_changed?(&1, existing_metadata)))
    required_metadata_updates = length(new_file_list)

    Logger.debug("New/changed files: #{FormatTools.format_pretty(new_file_list)}")

    new_changed_files = Enum.with_index(new_file_list) |> Enum.reduce(%{}, fn {path, idx}, metadata_map ->
      if not is_nil(progress_callback) do
        pct_done = trunc(idx / required_metadata_updates * 100)
        progress_callback.(pct_done)
      end
      Map.put(metadata_map, path, get_video_metadata(path))
    end)

    # TODO - I don't actually have to calculate this, can use \
    # Map.take instead of Map.drop but I'd like to have this diff available anyway for logging.
    deleted_files = Map.keys(existing_metadata) -- media_files

    Logger.debug("Deleted files: #{deleted_files}")

    new_metadata = existing_metadata |> Map.drop(deleted_files) |> Map.merge(new_changed_files)

    { :ok, new_metadata }
  end
end
