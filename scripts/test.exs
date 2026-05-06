state |> Map.new(fn record -> { record.path, %{ last_updated: record.last_updated, media_files: Map.new(record.media_files, fn record2 -> { record2.path, Map.delete(record2, :path) } end) }} end)
