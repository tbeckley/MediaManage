defmodule FormatTools do
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
end
