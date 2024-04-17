def frame_duration
  1024.0 / 44100.0 * 1000000.0
end

def get_closest_aligned_time(target_time)
  decimal_frames_to_target_time = target_time.to_f / frame_duration
  nearest_frame_index_for_target_time = decimal_frames_to_target_time.round
  puts "target_time: #{target_time}, decimal_frames_to_target_time: #{decimal_frames_to_target_time}, nearest_frame_index_for_target_time: #{nearest_frame_index_for_target_time}"
  nearest_frame_index_for_target_time * frame_duration
end

def generate_command_and_directives_for_segment(input_file, index, target_start, target_end, is_last)
  puts "--- segment #{index + 1} ---"

  start_time = get_closest_aligned_time(target_start)
  end_time = get_closest_aligned_time(target_end)
  puts "start_time: #{start_time}, end_time: #{end_time}"

  real_duration = end_time - start_time
  puts "real_duration: #{real_duration}"

  # We're subtracting two frames from the start time because ffmpeg allways internally
  # adds 2 frames of priming to the start of the stream.
  start_time_with_padding = [start_time - frame_duration * 2, 0].max

  # We add extra padding at the end, too, because ffmpeg tapers the last few frames
  # to avoid a pop when audio stops. We don't want tapering--we just want the signal.
  # So by shifting the end, we shift the taper past the content we care about it. We'll
  # chop off this tapered part using outpoint later.
  end_time_with_padding = end_time + frame_duration * 2
  puts "start_time_with_padding: #{start_time_with_padding}, end_time_with_padding: #{end_time_with_padding}"

  inpoint = 0

  if index > 0
    # We ask to also encode two frames before the start of our segment because
    # the AAC format is interframe. That is, the encoding of each frame depends
    # on the previous frame. This is also why AAC pads the start with silence.
    # By adding some extra padding ourselves, we ensure that the "real" data we
    # want will have been encoded as if the correct data preceded it. (Because
    # it did!)
    #
    # Note that, although we always set the extra time at the beginning to 2
    # frames here, it can actually be any value that's 2 frames or more. For
    # example, if you were encoding with echo, you might want to pad to account
    # for the full damping time of an echo.
    extra_time_at_beginning = frame_duration * 2
    start_time_with_padding = [start_time_with_padding - extra_time_at_beginning, 0].max

    # Although we only asked for two frames of padding, ffmpeg will add an
    # additional 2 frames of silence at the start of the segment. When we slice out
    # our real data with inpoint and outpoint, we'll want remove both the silence
    # and the extra frames we asked for.
    inpoint = frame_duration * 2 + extra_time_at_beginning
  end

  padded_duration = end_time_with_padding - start_time_with_padding
  puts "padded_duration: #{padded_duration}"

  # inpoint is inclusive and outpoint is exclusive. To avoid overlap, we subtract
  # the duration of one frame from the outpoint.
  # we don't have to subtract a frame if this is the last segment.
  subtract = frame_duration
  if is_last
    subtract = 0
  end
  outpoint = inpoint + real_duration - subtract

  # Things usually appear to work fine without the duration directive, but by
  # adding it, we make it so ffmpeg doesn't need to "guess" how long each
  # segment should be based on its sample count. Since we can do the math for
  # this at higher fidelity than ffmpeg, for very long outputs, it may help
  # avoid de-sync and make seeking more predictably exact.
  duration_directive = outpoint - inpoint + frame_duration

  puts "inpoint: #{inpoint}, outpoint: #{outpoint}"

  command =
    if ENV["NO_TRANSCODE"]
      # If we know the input file is AAC and we're not changing the sample rate,
      # we can create the segments without transcoding too. This works because,
      # if we cut at exactly the AAC frame boundaries, then we can just slice
      # out portions of the stream. Note, however, that -ss and -t flags are moved after
      # the input file so they're applied after the input file is read. Without that,
      # you'll get some funky output.
      "ffmpeg -hide_banner -loglevel error -nostats -y -i #{input_file} -c:a copy -ss #{start_time_with_padding}us -t #{padded_duration}us -f adts out/seg#{index + 1}.aac"
    else
      "ffmpeg -hide_banner -loglevel error -nostats -y -ss #{start_time_with_padding}us -t #{padded_duration}us -i #{input_file} -c:a libfdk_aac -ar 44100 -f adts out/seg#{index + 1}.aac"
    end

  directives = [
    "file 'seg#{index + 1}.aac'",
    "inpoint #{inpoint}us",
    "outpoint #{outpoint}us",
    "duration #{duration_directive}us"
  ]

  [command, directives.join("\n")]
end
