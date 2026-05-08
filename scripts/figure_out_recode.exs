import Recode
import FFmpex
use FFmpex.Options

in_path = "/home/teb/Videos/test-folder/atomic-taunt.mp4"
out_encoding = :hevc

in_metadata = Video.get_video_metadata(in_path, [:assume_ok])

preset = "superfast"

file_options_h265 = [
  option_vcodec("libx265"),
  option_acodec("copy"),
  option_vtag("hvc1"),
  option_f("mp4"),
  option_preset(preset),
  option_crf(26),
  option_tune("fastdecode")
]

output_file_name = in_path  <> ".x265"

if File.exists?(output_file_name) do
  #File.rm!(output_file_name)
end

IO.puts("Output will be to: #{output_file_name}")

global_opts = [
  option_v("error"),
  option_n(),
  option_progress("pipe:1"),
  option_xerror()
]

base_cmd = FFmpex.new_command() |> add_input_file(in_path) |> add_output_file(output_file_name)

with_global_opts = Enum.reduce(global_opts, base_cmd, fn opt, acc -> add_global_option(acc, opt) end)
full_cmd = Enum.reduce(file_options_h265, with_global_opts, fn opt, acc -> add_file_option(acc, opt) end)

{ bin, opts } = FFmpex.prepare(full_cmd)

full_opts = ["-stats_period", "5"] ++ opts

string_val = Enum.join([bin | full_opts], " ")

chunk_to_log = fn msg -> case Recode.time_from_chunk(msg) do
  nil -> :ok
  time when is_number(time) -> Recode.progress_callback(trunc(time * 100 / in_metadata.duration))
end end

result = Rambo.run(bin, full_opts, [{ :log, chunk_to_log }])
