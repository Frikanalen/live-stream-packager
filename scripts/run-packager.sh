#!/bin/sh
set -eu

output_dir=${OUTPUT_DIR:-/stream}
started_at=$(date +%s)
sequence=$((started_at / SEGMENT_DURATION_SECONDS))

# A container restart keeps the pod's emptyDir. Never let manifests from a
# previous process satisfy startup or readiness checks.
rm -f \
  "$output_dir/index.m3u8" \
  "$output_dir/index.mpd" \
  "$output_dir/audio.m3u8" \
  "$output_dir/video-low.m3u8" \
  "$output_dir/video-high.m3u8" \
  "$output_dir/stream_0.m3u8" \
  "$output_dir/stream_1.m3u8" \
  "$output_dir/stream_2.m3u8"

# Shaka only knows about segments from its current process. Remove orphaned
# media from older generations after clients' live-window grace period.
find "$output_dir" -maxdepth 1 -type f -name '*-[0-9]*.mp4' \
  -mmin "+$SEGMENT_RETENTION_MINUTES" -delete

exec packager "$@" \
  --hls_media_sequence_number="$sequence" \
  --start_segment_number="$sequence"
