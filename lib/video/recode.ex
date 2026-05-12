import FFmpex
use FFmpex.Options


defmodule Video.Recode do
  @behaviour Background.JobBehaviour

  @global_ffmpeg_encode_opts [
    option_v("error"),
    option_n(),
    option_progress("pipe:1"),
    option_xerror()
  ]

  @default_reencoding_opts { :hevc, "slow", 24 }

  def default_encoding() do
    @default_reencoding_opts
  end

  # I don't feel great about this. I _ALMOST_ feel that the new path should come from higher up the chain
  # So we're not just blindly trusting that the recode_file() function works properly
  defp get_recode_paths(input_path, codec, workdir \\ :nil) do
    { encode_supersuffix, output_extension } = case codec do
      :hevc -> { ".x265", ".mp4" }
      # :mp4 -> { ".x264", ".mp4" }
      # :av1 -> ".av1"
    end

    workpath = workdir || Path.dirname(input_path)

    workfile = Path.join(workpath, Path.basename(input_path) <> encode_supersuffix)
    final_file = Path.rootname(input_path) <> output_extension

    IO.puts(workfile)
    IO.puts(final_file)

    { workfile, final_file }
  end

  @impl Background.JobBehaviour
  def prepare_as_job(path, opts) do
    encoding_opts = case Map.get(opts, :encode_params) do
      nil ->
        # TODO - Logging
        # TODO - I might change this to be a hard failure.
        IO.puts("Couldn't find encoding options. Falling back on defaults.")
        @default_reencoding_opts
      opts -> opts
    end

    target_codec = elem(encoding_opts, 0)
    { work_file_path, final_file_path } = get_recode_paths(path, target_codec)

    cleanup_failed_fn = fn ->
      File.rm(work_file_path)
    end

    run_fn = fn progress_callback ->
        case recode_file_guarded({ path, work_file_path }, encoding_opts, progress_callback) do
          :ok ->
            # Delete the old file
            File.rm!(path)
            File.rename!(work_file_path, final_file_path)
            new_metadata = Video.get_video_metadata(final_file_path)
            { :ok, %{ final_file_path => new_metadata } }
          { :error, reason } ->
            # Cleanup on a failed recode for whatever reason
            cleanup_failed_fn.()
            { :error, reason }
        end
    end

    cond do
      !File.exists?(path) -> { :error, :enoent }
      File.exists?(work_file_path) -> { :error, :workfile_exists }
      File.exists?(final_file_path) and final_file_path != path -> { :error, :outfile_exists }
      :true -> { :ok, run_fn, cleanup_failed_fn }
    end
  end


  def recode_file(video_path, encoding_options, progress_callback \\ nil) do
    prepare_result = prepare_as_job(video_path, %{ encoding:  encoding_options })

    case prepare_result do
      { :ok, run_fn, cleanup_fn } ->
        try do
          run_fn.(progress_callback)
        rescue err ->
          cleanup_fn.()
          raise err
        catch err ->
          cleanup_fn.()
          throw err
        end
      { :error, reason } ->
        IO.puts("Some sort of error? #{inspect(reason)}")
        { :error, reason }
    end
  end

  defp recode_file_guarded({ input_file, work_file }, encoding_options, progress_callback) do
    # TODO - Enable maps for encoding options
    file_opts = case encoding_options do
      { :hevc, preset, crf } ->  [
        option_vcodec("libx265"),
        option_acodec("copy"),
        option_vtag("hvc1"),
        option_f("mp4"),
        option_preset(preset),
        option_crf(crf),
        option_tune("fastdecode") ]
      _ -> raise "Unknown encoding options! #{inspect(encoding_options)}"
    end

    # TODO - Allow different temp directory for encoding into and copying
    # TODO - Choose correct name suffix
    %{ duration: duration } = Video.get_video_metadata(input_file, [:assume_ok])

    base_cmd = FFmpex.new_command() |> add_input_file(input_file) |> add_output_file(work_file)
    with_global_opts = Enum.reduce(@global_ffmpeg_encode_opts, base_cmd, fn opt, acc -> add_global_option(acc, opt) end)
    full_cmd = Enum.reduce(file_opts, with_global_opts, fn opt, acc -> add_file_option(acc, opt) end)

    # FFmpex doesn't have a option_stats_period() and I don't want to add one :(
    # We have to run anyway via Rambo so we'll just cheat :)
    { bin, opts } = FFmpex.prepare(full_cmd)
    full_opts = ["-stats_period", "5"] ++ opts

    # For debugging
    # IO.puts(Enum.join([bin | full_opts], " "))
    log_behaviour = if is_function(progress_callback) do
      fn msg -> case FFmpegHelper.time_from_chunk(msg) do
        nil -> :ok
        time when is_number(time) -> progress_callback.(trunc(time * 100 / duration))
      end end
    else
      :false
    end

    case Rambo.run(bin, full_opts, [{ :log, log_behaviour }]) do
      { :error, e } -> { :error, { :ffmpeg, e } }
      { :ok, %Rambo{ status: status_code, err: stderr } } when status_code != 0 -> { :error, { :ffmpeg, stderr }}
      { :ok, %Rambo{ status: 0, err: stderr } } ->
        if FFmpegHelper.errmsg_is_error(stderr) do
          { :error, { :ffmpeg, stderr }}
        else
          :ok
        end
    end
  end
end
