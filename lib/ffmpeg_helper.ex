use FFmpex.Options

defmodule FFmpegHelper do
  def time_from_chunk({ msg_type, msg }) do
    # Chunks come in broken, so the out_time_ms line can be split
    # across multiple chunks. In that case we'll miss messages, but what can you do?
    # Other option would be a ring buffer of some sort or a GenServer, but I don't
    # Want to spin one of those up for this.
    match_regex = ~r/out_time_us=(\d+)\r?\n/

    case msg_type do
      :stderr -> nil
      :stdout -> case Regex.run(match_regex, msg) do
        [_, time_ms] -> String.to_integer(time_ms) / 1_000_000
        nil -> nil
      end
    end
  end

  # I really need a better way of matching on this...
  def errmsg_is_error(err_msg) do
    err_msg_lower = String.downcase(err_msg)

    # Yes, it returns status code zero and :ok when it fails. Sigh. Why even have the -n option?!
    known_error_patterns = [
      "already exists. exiting."
    ]

    String.contains?(err_msg_lower, "error") and String.contains?(err_msg_lower, known_error_patterns)
  end

  # TODO - Add more
  def ffmpeg_opts_from_encoding(encoding_settings) do
    case encoding_settings do
      { :hevc, preset, crf } ->  [
        option_vcodec("libx265"),
        option_acodec("copy"),
        option_vtag("hvc1"),
        option_f("mp4"),
        option_preset(preset),
        option_crf(crf),
        option_tune("fastdecode") ]
      _ -> raise "Unknown encoding options! #{inspect(encoding_settings)}"
    end
  end
end
