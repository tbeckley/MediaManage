base_paths = System.argv()

if Enum.empty?(base_paths) do
  IO.puts("Must supply at least one base path. Exiting.")
  exit(:shutdown)
end

if !Enum.all?(base_paths, &File.dir?/1) do
  IO.puts(:stderr, "At least one path is not a base media directory. Exiting.")
  exit(:shutdown)
end

# Need the uniq to cover a corner case with symlinks and the way gvfs mounts network drives...
media_to_process =  Enum.map(base_paths, &"#{&1}/**")
                    |> Enum.flat_map(&Path.wildcard/1)
                    |> Enum.filter(&.Video.video_file?/1)
                    |> Enum.uniq();

item_count = length(media_to_process)
IO.puts("Found #{item_count} media items")
metadata = media_to_process |> Stream.each(&IO.inspect/1) |> Stream.map(&MediaManage.get_metadata/1)

metadata = Enum.to_list(stream)
