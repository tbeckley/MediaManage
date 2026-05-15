defmodule FFmpegHelperTest do
  use ExUnit.Case
  doctest FFmpegHelper

  test "parses chunks correctly" do
    [ keystr | chunks ] = File.read!("test/assets/ffmpeg_chunks.txt") |> String.split("===CHUNK===")
    times = chunks |> Enum.map(&(FFmpegHelper.time_from_chunk({ :stdout, &1 })))

    # All this to take a moral stance against Code.eval_string()
    # Don't want an xz-utils situation!
    {:ok, tokens, _} = :erl_scan.string(String.to_charlist(keystr))
    {:ok, key} = :erl_parse.parse_term(tokens)

    assert key == times
  end

  # I don't want to check large files into git...
end
