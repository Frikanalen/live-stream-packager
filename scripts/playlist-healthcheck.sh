#!/bin/sh
set -eu

# PLAYLIST_PATHS is a space-separated list of media playlists. Every one must
# pass: renditions can stall independently (a mid-stream codec change once
# froze both video playlists while audio kept advancing).
mode=${1:-ready}
playlists=${PLAYLIST_PATHS:?PLAYLIST_PATHS is required}
max_age=${PLAYLIST_MAX_AGE_SECONDS:?PLAYLIST_MAX_AGE_SECONDS is required}
state_prefix=${HEALTH_STATE_PATH:-/tmp/playlist-health.state}
now=$(date +%s)

check() {
  playlist=$1
  state=$state_prefix.$(basename "$playlist" .m3u8)

  [ -s "$playlist" ] || return 1
  modified=$(stat -c %Y "$playlist" 2>/dev/null || stat -f %m "$playlist")
  age=$((now - modified))
  [ "$age" -ge 0 ] && [ "$age" -lt "$max_age" ] || return 1
  grep -q '^#EXTINF:' "$playlist" || return 1

  segment=$(awk '!/^#/ && NF { segment=$0 } END { print segment }' "$playlist")
  [ -n "$segment" ] || return 1
  segment=${segment%%\?*}
  case "$segment" in
    /*) segment_path=$segment ;;
    *) segment_path=$(dirname "$playlist")/$segment ;;
  esac
  [ -s "$segment_path" ] || return 1

  [ "$mode" = live ] || return 0

  previous=
  changed_at=$now
  if [ -f "$state" ]; then
    read -r previous changed_at < "$state" || true
  fi

  if [ "$segment" != "$previous" ]; then
    printf '%s %s\n' "$segment" "$now" > "$state"
    return 0
  fi

  [ $((now - changed_at)) -lt "$max_age" ]
}

status=0
for playlist in $playlists; do
  check "$playlist" || { echo "stale: $playlist" >&2; status=1; }
done
exit "$status"
