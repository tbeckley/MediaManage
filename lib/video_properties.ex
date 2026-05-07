use FFmpex.Options

defmodule VideoProperties do
  # List of supported media file extensions. Maybe this should change...
  @file_extension ["m4v", "mp4", "mkv", "webm", "avi"]

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

  def get_video_metadata(video_path) do
    IO.puts("Getting metadtata for #{video_path}")
    {:ok, %{:size => file_size, :mtime => modified_time }} = File.stat(video_path, [{:time, :posix}])

    case FFprobe.streams(video_path) do
      {:ok, streams} ->
        video_stream = Enum.find(streams, &(&1["codec_type"] == "video"))
        duration = FFprobe.duration(video_path);

        %{
          :broken => broken?(video_path),
          :modified_time => modified_time,
          :video_codec => Map.get(video_stream, "codec_name"),
          :duration => duration,
          :bps => trunc(file_size/duration)
        };
      {:error, :invalid_file} ->
        %{
          :broken => :true,
          :modified_time => modified_time
        }
    end
  end

  def recode_file(_video_path, _new_encoding, _progress_callback \\ nil) do
    IO.inspect("Shouldn't be here!")
    new_metadata = %{}
    { :ok, new_metadata }
  end

  defp file_changed?(path, existing_metadata) do
    modified_time = File.stat!(path, [{:time, :posix}]) |> Map.fetch!(:mtime)

    case get_in(existing_metadata, [path, :modified_time]) do
      nil -> :true
      ^modified_time -> :false
      _other_time -> :true
    end
  end

  # If existing_metadata is supplied, only get video metadata for files that
  def path_metadata_smart(path, existing_metadata \\ %{}) do
    if !File.dir?(path) do
      raise "Somehow tried to refresh not a path #{path}!"
    end

    media_files = Path.wildcard("#{path}/**") |> Enum.filter(&video_file?/1)

    new_file_list = media_files |> Enum.filter(&(file_changed?(&1, existing_metadata)))
    IO.puts("New/changed files")
    IO.puts(FormatTools.format_pretty(new_file_list))

    new_changed_files = new_file_list |> Map.new(&{ &1, get_video_metadata(&1) })

    deleted_files =  Map.keys(existing_metadata) -- media_files
    IO.puts("Deleted files")
    IO.puts(FormatTools.format_pretty(deleted_files))

    new_metadata = existing_metadata |> Map.drop(deleted_files) |> Map.merge(new_changed_files)

    { :ok, new_metadata }
  end
end
