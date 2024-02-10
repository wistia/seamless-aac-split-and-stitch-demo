require "fileutils"
require_relative "./calculations"

# Feel free to change these constants for your own testing.
SINE_WAVE_DURATION = 10.to_f
SINE_FREQUENCY = 10.to_f
TARGET_SEGMENT_DURATION = 1.0.to_f
SINE_WAVE_FILE_NAME = "sine-wave-#{SINE_WAVE_DURATION.to_i}-seconds.wav"

FileUtils.rm_rf "out"
FileUtils.mkdir_p "out"

# generate the sine wave we'll use as input
system("ffmpeg -hide_banner -loglevel error -nostats -y -f lavfi -i \"sine=frequency=#{SINE_FREQUENCY}:duration=#{SINE_WAVE_DURATION}\" out/#{SINE_WAVE_FILE_NAME}")

# Generate the commands we'll use to slice the sine wave into segments and the
# directives we'll use to recombine them later.
commands_and_directives = (SINE_WAVE_DURATION / TARGET_SEGMENT_DURATION).ceil.to_i.times.map do |i|
  start_time = (i * TARGET_SEGMENT_DURATION * 1000000).round.to_i
  end_time = [((i + 1) * TARGET_SEGMENT_DURATION * 1000000).round, SINE_WAVE_DURATION * 1000000].min.to_i
  is_last = i == (SINE_WAVE_DURATION / TARGET_SEGMENT_DURATION).ceil.to_i - 1
  generate_command_and_directives_for_segment(i, start_time, end_time, is_last)
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
