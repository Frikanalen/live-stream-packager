#!/bin/sh
set -eu

output_dir=${OUTPUT_DIR:-/stream}

# A container restart keeps the pod's emptyDir. Do not let playlists from the
# previous FFmpeg process satisfy startup or readiness checks.
rm -f \
  "$output_dir/index.m3u8" \
  "$output_dir/audio.m3u8" \
  "$output_dir/low.m3u8" \
  "$output_dir/high.m3u8" \
  "$output_dir/audio-init.mp4" \
  "$output_dir/low-init.mp4" \
  "$output_dir/high-init.mp4"

# FFmpeg only removes segments created by its current process. No remaining
# playlist references segments from the previous process, so remove that
# generation before starting a new one.
find "$output_dir" -maxdepth 1 -type f -name '*-[0-9]*.m4s' -delete

exec ffmpeg "$@"
