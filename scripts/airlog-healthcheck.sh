#!/bin/sh
# Liveness for the air log recorder: FFmpeg rewrites live.m3u8 after every
# segment, so an old playlist means nothing is being recorded.
set -eu

playlist=${AIRLOG_DIR:-/airlog}/live.m3u8
max_age=${AIRLOG_MAX_AGE_SECONDS:-60}

[ -s "$playlist" ] || { echo "no $playlist" >&2; exit 1; }
age=$(( $(date +%s) - $(stat -c %Y "$playlist") ))
if [ "$age" -gt "$max_age" ]; then
  echo "$playlist is ${age}s old (limit ${max_age}s)" >&2
  exit 1
fi
