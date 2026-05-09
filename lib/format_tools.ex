defmodule FormatTools do
  @encodings %{
    :hevc => "H.265 (hevc)",
    :h264 => "H.264",
    :av1 =>  "AV1"
  }

  def format_duration(nil) do "" end

  def format_duration(seconds_decimal) do
    seconds = trunc(seconds_decimal)

    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)
    s = rem(seconds, 60)

    cond do
      h > 0 -> "#{h}h#{m}m#{s}s"
      m > 0 -> "#{m}m#{s}s"
      :true -> "#{s}s"
    end
  end

  def format_codec(nil) do "" end

  def format_codec(codec) do
    case codec do
      "Alliance for Open Media AV1" -> "AV1"
      c -> c |> String.split() |> hd
    end
  end

  def format_bps(nil) do "" end

  def format_bps(bps) do
    "#{trunc(bps/1000)}kb/s"
  end

  def format_pretty(val) do
    inspect(val, [{ :limit, :infinity }, { :pretty, :true }])
  end

  def describe_job(spec) do
    case spec.type do
      # TODO - Include smarter encoding type checking
      :recode -> "Re-encode #{spec.path} to #{Map.get(@encodings, elem(spec.encode_opts, 0))}"
      :metadata -> "Update metadata on #{spec.path}"
      type -> "Do #{inspect(type)} (#{inspect(spec)}) on #{spec.path}"
    end
  end

  def format_job_error(error_data) do
    case error_data do
      { :ffmpeg, ffmpeg_msg } -> "FFMpeg error: #{ffmpeg_msg}"
      { :exception, e, stacktrace } -> "Please report this! \n Exception: #{inspect(e)}, \n Stacktrace: #{inspect(stacktrace)}"
      { :erlang, kind, reason } -> "Please report this! \n Erlang error: #{inspect(kind)}, #{inspect(reason)}"
      { :error, other } -> "Please report this! \n Unknown logic error: #{inspect(other, [{ :pretty, :true }])}"
    other -> "Please report this! \n Unknown logic error: #{inspect(other, [{ :pretty, :true }])}"
    end
  end
end
