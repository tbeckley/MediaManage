defmodule VideoTest do
  use ExUnit.Case
  doctest Video

  @asset_basedir "test/assets/video/"

  test "gets metadata correctly" do
    { :ok, metadata } = Video.path_metadata_smart(@asset_basedir)

    # Test the AV1 file read
    av1_metadata = Map.get(metadata, Path.join(@asset_basedir, "bbb-av1.mp4"))
    assert match?(%{ duration: 10, broken: false, video_codec: "av1", bps: 104554 }, av1_metadata)

    # Test the AV1 file read
    h264_metadata = Map.get(metadata, Path.join(@asset_basedir, "bbb-h264.mp4"))
    assert match?(%{ duration: 10, broken: false, video_codec: "h264", bps: 99101 }, h264_metadata)

    # Test the mkv file read
    # MKV is a container, not an encoding!
    mkv_metadata = Map.get(metadata, Path.join(@asset_basedir, "bbb-mkv.mkv"))
    assert match?(%{ duration: 10, broken: false, video_codec: "h264", bps: 95716 }, mkv_metadata)

    # Test the H265 file read
    h265_metadata = Map.get(metadata, Path.join(@asset_basedir, "jellyfish-h265.mp4"))
    assert match?(%{ duration: 10, broken: false, video_codec: "hevc", bps: 1058782 }, h265_metadata)

    # Test the pseudo-random-bytes file read
    broken_metadata = Map.get(metadata, Path.join(@asset_basedir, "broken-randombytes.mp4"))
    assert Map.get(broken_metadata, :broken) == true
    assert Map.get(broken_metadata, :video_codec) == :nil
  end
end
