#!/bin/sh
set -eu

# PLAYLIST_PATHS is a space-separated list of media playlists. Every one must
# pass: renditions can stall independently (a mid-stream codec change once
# froze both video playlists while audio kept advancing).
mode=${1:-ready}
playlists=${PLAYLIST_PATHS:?PLAYLIST_PATHS is required}
max_age=${PLAYLIST_MAX_AGE_SECONDS:?PLAYLIST_MAX_AGE_SECONDS is required}
state_prefix=${HEALTH_STATE_PATH:-/tmp/playlist-health.state}
# How many segments the renditions' newest segments may be apart. Every
# rendition numbers its segments from the same epoch start number and cuts them
# at the same length, so in step they are at most a segment or two apart.
# Further apart, no player can line them up -- on 2026-11-13 staging's audio
# ran 491 segments behind its video for ten hours while every playlist kept
# advancing. 0 turns the check off.
max_skew=${PLAYLIST_MAX_SKEW_SEGMENTS:-5}
now=$(date +%s)
newest_numbers=

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

  # The trailing number of the segment's name, e.g. 1794569308 in
  # audio-1794569308.m4s.
  number=$(basename "$segment" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)\.[^.]*$/\1/p')
  [ -n "$number" ] && newest_numbers="$newest_numbers $number"

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

# Whether the renditions' newest segments are within max_skew of each other.
in_step() {
  [ "$max_skew" -gt 0 ] || return 0
  set -- $newest_numbers
  [ "$#" -ge 2 ] || return 0
  lowest=$1
  highest=$1
  for number; do
    [ "$number" -lt "$lowest" ] && lowest=$number
    [ "$number" -gt "$highest" ] && highest=$number
  done
  [ $((highest - lowest)) -le "$max_skew" ] || {
    echo "out of step: newest segments span $lowest..$highest, more than $max_skew apart" >&2
    return 1
  }
}

status=0
for playlist in $playlists; do
  check "$playlist" || { echo "stale: $playlist" >&2; status=1; }
done
# Only liveness acts on it: a restart is what put the renditions back in step,
# and readiness failing would only take the stream out of the Service while
# leaving the process wedged.
if [ "$mode" = live ]; then
  in_step || status=1
fi
exit "$status"
