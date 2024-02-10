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
    # We ask to also encode two frames before the start of our segment because
    # the AAC format is interframe. That is, the encoding of each frame depends
    # on the previous frame. This is also why AAC pads the start with silence.
    # By adding some extra padding ourselves, we ensure that the "real" data we
    # want will have been encoded as if the correct data preceded it.  (Because
    # it did!)
    start_time_with_padding = [start_time_with_padding - frame_duration * 2, 0].max

    # Although we only asked for two frames of padding, ffmpeg will add an
    # additional 2 frames of silence at the start of the segment. When we slice out
    # our real data with inpoint and outpoint, we'll want remove both the silence
    # and the extra frames we asked for.
    inpoint = frame_duration * 4
  end

  padded_duration = end_time_with_padding - start_time_with_padding
  puts "padded_duration: #{padded_duration}"

  # inpoint is inclusive and outpoint is exclusive. To avoid overlap, we subtract
  # the duration of one frame from the outpoint.
  outpoint = inpoint + real_duration - frame_duration

  puts "inpoint: #{inpoint}, outpoint: #{outpoint}"

  command = "ffmpeg -hide_banner -loglevel error -nostats -y -ss #{start_time_with_padding}us -t #{padded_duration}us -i out/#{SINE_WAVE_FILE_NAME} -c:a libfdk_aac -ar 44100 -f adts out/seg#{index + 1}.aac"
  directives = [
    "file 'seg#{index + 1}.aac'",
    "inpoint #{inpoint}us",
    "outpoint #{outpoint}us"
  ]

  [command, directives.join("\n")]
end
