require "fileutils"
require "uri"
require "net/http"
require_relative "./calculations"

# Feel free to change these constants for your own testing.
SINE_WAVE_DURATION = 10.to_f
SINE_FREQUENCY = 10.to_f
DEFAULT_SEGMENT_DURATION = 1.0.to_f
SINE_WAVE_FILE_NAME = "sine-wave-#{SINE_WAVE_DURATION.to_i}-seconds.wav"

FileUtils.rm_rf "out"
FileUtils.mkdir_p "out"

input_file = nil

if ARGV.count == 1 && ARGV[0] !~ /\A-?\d+(\.\d+)?\z/
  input_file = ARGV[0]
  target_segment_duration = DEFAULT_SEGMENT_DURATION
else
  target_segment_duration = (ARGV[0] || DEFAULT_SEGMENT_DURATION).to_f
end

if target_segment_duration <= 0
  raise "Segment duration must be greater than 0"
end

if ARGV.count == 2
  input_file = ARGV[1]
end

if input_file&.start_with?(/^https?:\/\//)
  uri = URI.parse(input_file)
  puts "Downloading file from #{uri}..."
  resp = Net::HTTP.get_response(uri)
  if resp.code.to_i != 200
    raise "Failed to download file: #{resp.code.inspect}"
  end
  File.write("out/downloaded-file", resp.body)
  input_file = "out/downloaded-file"
elsif input_file
  puts "Using local file #{input_file}"
else
  # generate the sine wave we'll use as input
  system("ffmpeg -hide_banner -loglevel error -nostats -y -f lavfi -i \"sine=frequency=#{SINE_FREQUENCY}:duration=#{SINE_WAVE_DURATION}\" out/#{SINE_WAVE_FILE_NAME}")
  input_file = "out/#{SINE_WAVE_FILE_NAME}"
end

if input_file.end_with?(".mp3")
  # Something about mp3s make it so they have extra padding between them when
  # split. Remuxing to mkv fixes it.
  #
  # NOTE: There may be other formats that benefit from remuxing to MKV too.
  puts "Detected mp3 input file. Remuxing to mkv..."
  remux_cmd = "ffmpeg -hide_banner -loglevel error -nostats -y -i #{input_file} -c copy out/remuxed.mkv"
  puts remux_cmd
  system(remux_cmd)
  input_file = "out/remuxed.mkv"
end

duration_cmd = "ffprobe -hide_banner -loglevel error -select_streams a:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 #{input_file}"
puts duration_cmd
duration = `#{duration_cmd}`.to_f
puts "Input file duration: #{duration}"

# Generate the commands we'll use to slice the sine wave into segments and the
# directives we'll use to recombine them later.
commands_and_directives = (duration / target_segment_duration).ceil.to_i.times.map do |i|
  start_time = (i * target_segment_duration * 1000000).round.to_i
  end_time = [((i + 1) * target_segment_duration * 1000000).round, duration * 1000000].min.to_i
  is_last = i == (duration / target_segment_duration).ceil.to_i - 1
  generate_command_and_directives_for_segment(input_file, i, start_time, end_time, is_last)
end

all_directives = commands_and_directives.map { |cmd, directives| directives }.join("\n")
File.write("out/audio-concat.txt", all_directives)

puts "---"

# Run the commands.
commands_and_directives.each do |cmd, _|
  puts cmd
  system(cmd)
end

puts "---"

# Stitch the segments back together.
concat_cmd = "ffmpeg -hide_banner -loglevel error -nostats -y -f concat -i out/audio-concat.txt -c copy out/stitched.mp4"
puts concat_cmd
puts all_directives
system(concat_cmd)
