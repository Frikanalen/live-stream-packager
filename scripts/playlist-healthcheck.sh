#!/bin/sh
set -eu

# PLAYLIST_PATHS is a space-separated list of media playlists. Every one must
# pass: renditions can stall independently (a mid-stream codec change once
# froze both video playlists while audio kept advancing).
#
# In live mode the renditions must also agree with each other and with the
# clock. Advancing is not enough: on 2026-11-13 a CPU-starved FFmpeg kept
# writing all three playlists for ten hours with audio ~16 minutes behind
# video and video ~79 minutes behind the wall clock, which no player can
# line up. Each playlist's last EXT-X-PROGRAM-DATE-TIME plus that segment's
# duration is where the rendition ends; those ends must lie within
# PLAYLIST_MAX_SKEW_SECONDS of each other and within
# PLAYLIST_MAX_LAG_SECONDS of now. Playlists without program date times skip
# these two checks.
mode=${1:-ready}
playlists=${PLAYLIST_PATHS:?PLAYLIST_PATHS is required}
max_age=${PLAYLIST_MAX_AGE_SECONDS:?PLAYLIST_MAX_AGE_SECONDS is required}
max_skew=${PLAYLIST_MAX_SKEW_SECONDS:-6}
max_lag=${PLAYLIST_MAX_LAG_SECONDS:-300}
state_prefix=${HEALTH_STATE_PATH:-/tmp/playlist-health.state}
now=$(date +%s)
ends=

# Print where the playlist's last segment ends, in Unix seconds, from its
# last EXT-X-PROGRAM-DATE-TIME and the EXTINF that follows it. Prints nothing
# if the playlist has no program date time. Plain arithmetic rather than
# mktime(), which BusyBox awk builds do not all have.
playlist_end() {
  awk '
    function days_from_civil(y, m, d,    era, yoe, doy, doe) {
      y -= (m <= 2)
      era = int((y >= 0 ? y : y - 399) / 400)
      yoe = y - era * 400
      doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
      doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
      return era * 146097 + doe - 719468
    }
    function to_epoch(ts,    date, time, zone, sign, zh, zm, parts, hms) {
      # 2026-11-13T17:22:18.977+0000, ...Z or ...+00:00
      date = substr(ts, 1, 10)
      time = substr(ts, 12)
      zone = 0
      if (match(time, /[Zz]$/)) {
        time = substr(time, 1, RSTART - 1)
      } else if (match(time, /[+-][0-9][0-9]:?[0-9][0-9]$/)) {
        sign = substr(time, RSTART, 1) == "-" ? -1 : 1
        zh = substr(time, RSTART + 1, 2)
        zm = substr(time, RLENGTH + RSTART - 2, 2)
        zone = sign * (zh * 3600 + zm * 60)
        time = substr(time, 1, RSTART - 1)
      }
      split(date, parts, "-")
      split(time, hms, ":")
      return days_from_civil(parts[1] + 0, parts[2] + 0, parts[3] + 0) * 86400 \
        + hms[1] * 3600 + hms[2] * 60 + hms[3] - zone
    }
    /^#EXT-X-PROGRAM-DATE-TIME:/ { pdt = substr($0, 26); duration = 0; next }
    /^#EXTINF:/ { split(substr($0, 9), f, ","); duration = f[1] + 0 }
    END { if (pdt != "") printf "%.3f\n", to_epoch(pdt) + duration }
  ' "$1"
}

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

  end=$(playlist_end "$playlist")
  [ -z "$end" ] || ends="$ends $(basename "$playlist" .m3u8)=$end"

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

if [ "$mode" = live ] && [ -n "$ends" ]; then
  # shellcheck disable=SC2086 # one word per rendition
  printf '%s\n' $ends | awk -F= -v now="$now" -v max_skew="$max_skew" -v max_lag="$max_lag" '
    { end[$1] = $2 + 0; if (n++ == 0 || $2 + 0 < lo) lo = $2 + 0; if (n == 1 || $2 + 0 > hi) hi = $2 + 0 }
    END {
      bad = 0
      if (hi - lo > max_skew) {
        printf "out of sync: renditions end %.1fs apart (max %ss):", hi - lo, max_skew > "/dev/stderr"
        for (r in end) printf " %s=%.1fs", r, end[r] - now > "/dev/stderr"
        printf "\n" > "/dev/stderr"
        bad = 1
      }
      lag = now - hi; if (lag < 0) lag = -lag
      if (lag > max_lag) {
        printf "off the clock: newest rendition ends %.1fs from now (max %ss)\n", now - hi, max_lag > "/dev/stderr"
        bad = 1
      }
      exit bad
    }
  ' || status=1
fi

exit "$status"
