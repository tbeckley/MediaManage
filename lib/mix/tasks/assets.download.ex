defmodule Mix.Tasks.Assets.Download do
  use Mix.Task

  @shortdoc "Downloads and generates video assets for test"

  @video_downloads [
    { "bbb-av1.mp4", "https://test-videos.co.uk/vids/bigbuckbunny/mp4/av1/360/Big_Buck_Bunny_360_10s_1MB.mp4" },
    { "bbb-h264.mp4", "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4" },
    { "bbb-mkv.mkv", "https://test-videos.co.uk/vids/bigbuckbunny/mkv/360/Big_Buck_Bunny_360_10s_1MB.mkv" },
    { "jellyfish-h265.mp4", "https://test-videos.co.uk/vids/jellyfish/mp4/h265/1080/Jellyfish_1080_10s_10MB.mp4" }
  ]

  def run(_) do
    video_asset_dir = "test/assets/video"
    File.mkdir_p!(video_asset_dir)

    Enum.each(@video_downloads, fn { filename, url } ->
      download_path = Path.join(video_asset_dir, filename)
      if not File.exists?(download_path) do
        Mix.shell().info("Downloading #{url} -> #{filename}")
        { _, 0 } = System.cmd("curl", ["-L", "-s", "-o", download_path, url])
      end
    end)


    broken_filename = "broken-randombytes.mp4"
    :rand.seed(:default, 0)
    pseudo_rand_data = :rand.bytes(1024)
    File.write!(Path.join(video_asset_dir, broken_filename), pseudo_rand_data)
  end
end
