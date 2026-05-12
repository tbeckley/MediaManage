use FFmpex.Options

defmodule Video do
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

  def get_video_metadata(video_path, opts \\ []) do
    assume_ok = :assume_ok in opts

    # TODO - Logging
    # IO.puts("Getting metadata for #{video_path}")
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

  @spec module_for(:recode | :metadata) :: module()
  def module_for(:recode), do: Video.Recode
  def module_for(:metadata), do: Video.Metadata
end
