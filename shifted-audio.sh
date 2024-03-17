ffmpeg -i sine.wav -filter_complex "atrim=start_sample=0:end_sample=80000" -y trimmed.wav
ffmpeg -i trimmed.wav -filter_complex "atempo=2" -y spedup.wav
