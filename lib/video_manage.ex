use FFmpex.Options

defmodule VideoManage do
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

  def get_metadata(video_path) do
    {:ok, %{:size => file_size, :mtime => modified_time }} = File.stat(video_path, [{:time, :posix}])

    case FFprobe.streams(video_path) do
      {:ok, streams} ->
        video_stream = Enum.find(streams, &(&1["codec_type"] == "video"))
        duration = FFprobe.duration(video_path);

        bit_rate = case Map.get(video_stream, "bit_rate") do
          nil -> nil
          value when is_bitstring(value) -> String.to_integer(value)
          value -> value
        end

        %{:path => video_path,
          :broken => broken?(video_path),
          :modified_time => modified_time,
          :video_codec => Map.get(video_stream, "codec_long_name"),
          :duration => duration,
          :bit_rate => bit_rate,
          :bps => trunc(file_size/duration)
        }
      {:error, :invalid_file} ->
        %{:path => video_path,
          :broken => :true,
          :modified_time => modified_time
        }
    end
  end
end
