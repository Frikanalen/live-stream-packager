#!/bin/sh
# Air log recorder: a low-quality copy of what the stream carries, cut into
# self-contained MPEG-TS segments named by their UTC start time,
#   $AIRLOG_DIR/YYYY-MM-DD/HH/YYYYMMDDTHHMMSSZ.ts
# Django (airlog app) lists them straight from disk; there is no index to
# keep in step. A segment only appears under its final name once it is
# complete (temp_file), so a listed segment is always playable. live.m3u8 is
# only there for the liveness probe (scripts/airlog-healthcheck.sh).
set -eu

airlog_dir=${AIRLOG_DIR:-/airlog}
input_url=${AIRLOG_INPUT_URL:?AIRLOG_INPUT_URL is required}
segment_seconds=${AIRLOG_SEGMENT_SECONDS:-10}
video_height=${AIRLOG_VIDEO_HEIGHT:-360}
video_fps=${AIRLOG_VIDEO_FPS:-25}
video_bitrate=${AIRLOG_VIDEO_BITRATE:-400k}
audio_bitrate=${AIRLOG_AUDIO_BITRATE:-64k}
audio_channels=${AIRLOG_AUDIO_CHANNELS:-1}

# Segment names come from the wall clock, which must be UTC.
export TZ=UTC

# A segment the previous process left half-written never got its final name.
find "$airlog_dir" -name '*.ts.tmp' -delete 2>/dev/null || true
rm -f "$airlog_dir/live.m3u8"

gop=$((video_fps * 2))

exec ffmpeg -hide_banner -nostats -loglevel warning \
  -rw_timeout 15000000 -probesize 20M -noautorotate \
  -i "$input_url" \
  -map 0:v:0 -map 0:a:0 \
  -vf "scale=-2:${video_height},fps=${video_fps},format=yuv420p" \
  -c:v libx264 -preset veryfast -profile:v main \
  -b:v "$video_bitrate" -maxrate "$video_bitrate" -bufsize "$video_bitrate" \
  -g "$gop" -keyint_min "$gop" -sc_threshold 0 \
  -c:a aac -b:a "$audio_bitrate" -ac "$audio_channels" -ar 48000 \
  -f hls -hls_time "$segment_seconds" -hls_list_size 6 \
  -hls_segment_type mpegts -hls_flags temp_file+program_date_time \
  -strftime 1 -strftime_mkdir 1 \
  -hls_segment_filename "$airlog_dir/%Y-%m-%d/%H/%Y%m%dT%H%M%SZ.ts" \
  "$airlog_dir/live.m3u8"
