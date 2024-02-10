SINE_WAVE_DURATION = 10.to_f
SINE_FREQUENCY = 1000.to_f
TARGET_SEGMENT_DURATION = 1.0.to_f
SINE_WAVE_FILE_NAME = "sine-wave-#{SINE_WAVE_DURATION.to_i}-seconds.wav"

def frame_duration
  1024.0 / 44100.0 * 1000000.0
end

def get_closest_aligned_time(target_time)
	decimal_frames_to_target_time = target_time.to_f / frame_duration
	nearest_frame_index_for_target_time = decimal_frames_to_target_time.round
  puts "target_time: #{target_time}, decimal_frames_to_target_time: #{decimal_frames_to_target_time}, nearest_frame_index_for_target_time: #{nearest_frame_index_for_target_time}"
	nearest_frame_index_for_target_time * frame_duration
end

def generate_command_and_directives_for_segment(index, target_start, target_end)
  puts "--- segment #{index + 1} ---"

  start_time = get_closest_aligned_time(target_start)
  end_time = get_closest_aligned_time(target_end)
  puts "start_time: #{start_time}, end_time: #{end_time}"

  real_duration = end_time - start_time
  puts "real_duration: #{real_duration}"

  start_time_with_padding = [start_time - frame_duration * 2, 0].max
  end_time_with_padding = end_time + frame_duration * 2
  puts "start_time_with_padding: #{start_time_with_padding}, end_time_with_padding: #{end_time_with_padding}"

  inpoint = 0
  if index > 0
    inpoint = frame_duration * 2
    start_time_with_padding = [start_time_with_padding - frame_duration * 2, 0].max
    inpoint += frame_duration * 2
  end 

  padded_duration = end_time_with_padding - start_time_with_padding
  puts "padded_duration: #{padded_duration}"

  outpoint = inpoint + real_duration - frame_duration

  puts "inpoint: #{inpoint}, outpoint: #{outpoint}"

  command = "ffmpeg -hide_banner -loglevel error -nostats -y -ss #{start_time_with_padding}us -t #{padded_duration}us -i #{SINE_WAVE_FILE_NAME} -c:a libfdk_aac -ar 44100 -f adts seg#{index + 1}.aac"
  directives = [
    "file 'seg#{index + 1}.aac'",
    "inpoint #{inpoint}us",
    "outpoint #{outpoint}us"
  ]

  [command, directives.join("\n")]
end

system("ffmpeg -hide_banner -loglevel error -nostats -y -f lavfi -i \"sine=frequency=#{SINE_FREQUENCY}:duration=#{SINE_WAVE_DURATION}\" #{SINE_WAVE_FILE_NAME}")

commands_and_directives = (SINE_WAVE_DURATION / TARGET_SEGMENT_DURATION).ceil.to_i.times.map do |i|
  start_time = (i * TARGET_SEGMENT_DURATION * 1000000).round.to_i
  end_time = [((i + 1) * TARGET_SEGMENT_DURATION * 1000000).round, SINE_WAVE_DURATION * 1000000].min.to_i
  cmd, directives = generate_command_and_directives_for_segment(i, start_time, end_time)
end

all_directives = commands_and_directives.map { |cmd, directives| directives }.join("\n")
File.write("audio-concat.txt", all_directives)

puts "---"

commands_and_directives.each do |cmd, _|
  puts cmd
  system(cmd)
end

puts "---"

concat_cmd = "ffmpeg -hide_banner -loglevel error -nostats -y -f concat -i audio-concat.txt -c copy stitched.mp4"
puts concat_cmd
puts all_directives
system(concat_cmd)
