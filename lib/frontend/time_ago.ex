defmodule Frontend.TimeAgo do
  @minute 60
  @hour 60 * @minute
  @day 24 * @hour
  @week 7 * @day
  @month 30 * @day
  @year 35 * @day

  def ago(nil) do
    "never"
  end

  def ago(seconds) when seconds < @minute do
    "less than a minute ago"
  end

  def ago(seconds) when seconds < @hour do
    "#{div(seconds, @minute)} min ago"
  end

  def ago(seconds) when seconds < @day do
    "#{div(seconds, @hour)} hours ago"
  end

  def ago(seconds) when seconds < @week do
    "#{div(seconds, @day)} days ago"
  end

  def ago(seconds) when seconds < @month do
    "#{div(seconds, @week)} weeks ago"
  end

  def ago(seconds) when seconds < @year do
    "#{div(seconds, @month)} months ago"
  end

  def ago(seconds) do
    "#{div(seconds, @year)} years ago"
  end
end
