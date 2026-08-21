#!/bin/sh
set -eu

mode=${1:-ready}
playlist=${PLAYLIST_PATH:?PLAYLIST_PATH is required}
max_age=${PLAYLIST_MAX_AGE_SECONDS:?PLAYLIST_MAX_AGE_SECONDS is required}
state=${HEALTH_STATE_PATH:-/tmp/playlist-health.state}
now=$(date +%s)

[ -s "$playlist" ] || exit 1
modified=$(stat -c %Y "$playlist" 2>/dev/null || stat -f %m "$playlist")
age=$((now - modified))
[ "$age" -ge 0 ] && [ "$age" -lt "$max_age" ] || exit 1
grep -q '^#EXTINF:' "$playlist" || exit 1

segment=$(awk '!/^#/ && NF { segment=$0 } END { print segment }' "$playlist")
[ -n "$segment" ] || exit 1
segment=${segment%%\?*}
case "$segment" in
  /*) segment_path=$segment ;;
  *) segment_path=$(dirname "$playlist")/$segment ;;
esac
[ -s "$segment_path" ] || exit 1

[ "$mode" = live ] || exit 0

previous=
changed_at=$now
if [ -f "$state" ]; then
  read -r previous changed_at < "$state" || true
fi

if [ "$segment" != "$previous" ]; then
  printf '%s %s\n' "$segment" "$now" > "$state"
  exit 0
fi

[ $((now - changed_at)) -lt "$max_age" ]
