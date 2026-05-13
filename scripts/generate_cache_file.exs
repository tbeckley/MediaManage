{data, []} = File.read!("out/cache.txt") |> Code.eval_string()

all_files = data |> Enum.map(fn f ->
  case f do
    %{path: path,
      modified_time: modified_time,
      broken: broken,
      bps: bps,
      duration: duration,
      bit_rate: bit_rate,
      video_codec: video_codec
    } ->
      br = cond do
        is_nil(bit_rate) -> nil
        is_integer(bit_rate) -> bit_rate
        is_bitstring(bit_rate) -> String.to_integer(bit_rate)
      end

      %{
        path: path,
        modified_time: modified_time,
        broken: broken,
        bit_rate: br,
        bps: bps,
        duration: duration,
        video_codec: video_codec
      }
    %{path: path,
      modified_time: modified_time,
      broken: broken
    } -> %{
      path: path,
      modified_time: modified_time,
      broken: broken
    }
    _ -> FormatTools.format_pretty(f)
  end
end)

movies = Enum.filter(all_files, &(String.contains?(&1.path, "/mnt/solaria/content/Movies")))
tv = Enum.filter(all_files, &(String.contains?(&1.path, "/mnt/solaria/content/TV")))

cache = [
  %{
    path: "/mnt/solaria/content/Movies",
    last_updated: 1777693941,
    media_files: movies
  },
  %{
    path: "/mnt/solaria/content/TV",
    last_updated: 1777693941,
    media_files: tv
  }
]

bin_data = :erlang.term_to_binary(cache, [:compressed, :deterministic])

File.write("out/cache", bin_data)
