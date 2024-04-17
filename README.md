# Seamless AAC Split and Stitch Demo

This repo demonstrates calculations and ffmpeg commands to encode portions of an audio file with the AAC codec and to recombine them without transcoding and without any skips or glitches.

https://github.com/wistia/seamless-aac-split-and-stitch-demo/assets/493992/3a88dfda-f345-4518-9e86-696c14ae4a2b

The general rule is that, when choosing your audio segment sizes, they _need_ to be aligned with AAC frame boundaries. With aligned frame boundaries, we can use the concat demuxer to cut out the silence ffmpeg adds, as well as some extra padding we add to account for AAC's dependency on previous frames.

This tech is important because it allows faster and more efficient cloud rendering. It may also be used, for example, to render and mux individual HLS segments (TS files) independently of the full file.

I've added more comments and explanations in the code itself.

## Requirements

This demo assumes ffmpeg is installed and compiled with support for the libfdk_aac codec. It also assumes you have a modern version of ruby installed.

Some versions of ffmpeg (around 5) may not work properly as there was a temporary regression with aac concatenation. ffmpeg 6 seems to work well. The author's build config looks like this:

```
ffmpeg version 6.0 Copyright (c) 2000-2023 the FFmpeg developers
  built with Apple clang version 15.0.0 (clang-1500.0.40.1)
  configuration: --prefix=/Users/maxschnur/.asdf/installs/ffmpeg/6.0 --enable-gpl --enable-libass --enable-libfdk-aac --enable-libmp3lame --enable-libopenjpeg --enable-libopus --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxvid --enable-libzimg --enable-nonfree --enable-openssl --enable-shared
```

## Usage

Split and stitch with the defaults:

    ruby run.rb

Test with your own input files and different target segment durations:

    ruby run.rb 0.5 <path-or-url>

You can find all artifacts in the "out" directory:

    ls out

If you know you're operating on an input file that's 44.1KHz, you can also split up the file without transcoding. Try a command like this to test it out:

    NO_TRANSCODE=1 ruby run.rb 1.0 <your-file-with-an-aac-input-stream>

On a Mac, you may want to examine out/stitched.mp4 with a visualization program. The author uses [Audacity](https://www.audacityteam.org/) for that.

    open -a Audacity out/stitched.mp4

NOTE: This repo hardcodes the sample rate as 44.1KHz to simplify the demo code. But this method should work with any sample rate.
