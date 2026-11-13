#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

for script in "$repo_dir"/scripts/*.sh; do
  sh -n "$script"
done

playlist_dir="$test_dir/playlist"
mkdir -p "$playlist_dir"

# write_playlist NAME N: point NAME.m3u8 at a fresh segment NAME-N.mp4.
write_playlist() {
  printf 'segment %s\n' "$2" > "$playlist_dir/$1-$2.mp4"
  printf '#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:%s\n#EXTINF:2.0,\n%s-%s.mp4\n' \
    "$2" "$1" "$2" > "$playlist_dir/$1.m3u8"
}

for rendition in audio high; do
  write_playlist "$rendition" 1
done

PLAYLIST_PATHS="$playlist_dir/audio.m3u8 $playlist_dir/high.m3u8"
PLAYLIST_MAX_AGE_SECONDS=30
HEALTH_STATE_PATH="$test_dir/playlist.state"
export PLAYLIST_PATHS PLAYLIST_MAX_AGE_SECONDS HEALTH_STATE_PATH

sh "$repo_dir/scripts/playlist-healthcheck.sh" ready
sh "$repo_dir/scripts/playlist-healthcheck.sh" live

printf 'audio-1.mp4 1\n' > "$HEALTH_STATE_PATH.audio"
printf 'high-1.mp4 1\n' > "$HEALTH_STATE_PATH.high"
if sh "$repo_dir/scripts/playlist-healthcheck.sh" live; then
  echo 'unchanged playlists unexpectedly passed liveness' >&2
  exit 1
fi

# Audio advancing alone must not hide a stalled video rendition.
write_playlist audio 2
if sh "$repo_dir/scripts/playlist-healthcheck.sh" live; then
  echo 'stalled video playlist unexpectedly passed liveness' >&2
  exit 1
fi

write_playlist audio 3
write_playlist high 2
sh "$repo_dir/scripts/playlist-healthcheck.sh" live

# write_dated_playlist NAME N OFFSET: like write_playlist, with the segment's
# program date time OFFSET seconds from now (segment is 2 s long).
write_dated_playlist() {
  start=$(( $(date +%s) + $3 - 2 ))
  pdt=$(date -u -d "@$start" '+%Y-%m-%dT%H:%M:%S.500+0000')
  printf 'segment %s\n' "$2" > "$playlist_dir/$1-$2.mp4"
  printf '#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:%s\n#EXT-X-PROGRAM-DATE-TIME:%s\n#EXTINF:2.000000,\n%s-%s.mp4\n' \
    "$2" "$pdt" "$1" "$2" > "$playlist_dir/$1.m3u8"
}

# In step with each other and with the clock.
write_dated_playlist audio 10 0
write_dated_playlist high 10 1
sh "$repo_dir/scripts/playlist-healthcheck.sh" live
sh "$repo_dir/scripts/playlist-healthcheck.sh" ready

# Both advancing, but audio 16 minutes behind video: the 2026-11-13 wedge.
write_dated_playlist audio 11 -982
write_dated_playlist high 11 0
if sh "$repo_dir/scripts/playlist-healthcheck.sh" live; then
  echo 'renditions 16 minutes apart unexpectedly passed liveness' >&2
  exit 1
fi
# Readiness does not judge sync: a failing liveness probe restarts FFmpeg.
sh "$repo_dir/scripts/playlist-healthcheck.sh" ready

# In step with each other, but far behind the wall clock.
write_dated_playlist audio 12 -4740
write_dated_playlist high 12 -4740
if sh "$repo_dir/scripts/playlist-healthcheck.sh" live; then
  echo 'renditions 79 minutes behind the clock unexpectedly passed liveness' >&2
  exit 1
fi

# Offsets written as Z and +00:00 parse the same way.
write_dated_playlist audio 13 0
sed -i.bak 's/+0000$/Z/' "$playlist_dir/audio.m3u8"
write_dated_playlist high 13 0
sed -i.bak 's/+0000$/+00:00/' "$playlist_dir/high.m3u8"
sh "$repo_dir/scripts/playlist-healthcheck.sh" live

# A non-UTC offset is honoured: 19:00+0200 is 17:00Z.
start=$(( $(date +%s) - 2 ))
local_pdt=$(date -u -d "@$((start + 7200))" '+%Y-%m-%dT%H:%M:%S.500+0200')
write_dated_playlist audio 14 0
write_dated_playlist high 14 0
sed -i.bak "s/^#EXT-X-PROGRAM-DATE-TIME:.*/#EXT-X-PROGRAM-DATE-TIME:$local_pdt/" "$playlist_dir/high.m3u8"
sh "$repo_dir/scripts/playlist-healthcheck.sh" live

snmp_file="$test_dir/snmp"
cubemap_state="$test_dir/cubemap.state"
cat > "$snmp_file" <<'EOF'
Udp: InDatagrams NoPorts InErrors OutDatagrams RcvbufErrors SndbufErrors InCsumErrors IgnoredMulti MemErrors
Udp: 100 0 0 0 0 0 0 0 0
EOF
CUBEMAP_INPUT_MAX_AGE_SECONDS=30
CUBEMAP_HEALTH_STATE_PATH="$cubemap_state"
CUBEMAP_SNMP_FILE="$snmp_file"
export CUBEMAP_INPUT_MAX_AGE_SECONDS CUBEMAP_HEALTH_STATE_PATH CUBEMAP_SNMP_FILE

if sh "$repo_dir/scripts/cubemap-input-healthcheck.sh"; then
  echo 'Cubemap passed readiness before observing a datagram' >&2
  exit 1
fi

cat > "$snmp_file" <<'EOF'
Udp: InDatagrams NoPorts InErrors OutDatagrams RcvbufErrors SndbufErrors InCsumErrors IgnoredMulti MemErrors
Udp: 101 0 0 0 0 0 0 0 0
EOF
sh "$repo_dir/scripts/cubemap-input-healthcheck.sh"
sh "$repo_dir/scripts/cubemap-input-healthcheck.sh"

printf '101 1\n' > "$cubemap_state"
if sh "$repo_dir/scripts/cubemap-input-healthcheck.sh"; then
  echo 'stale Cubemap input unexpectedly passed readiness' >&2
  exit 1
fi

ffmpeg_dir="$test_dir/ffmpeg"
mkdir -p "$ffmpeg_dir/bin" "$ffmpeg_dir/output"
cat > "$ffmpeg_dir/bin/ffmpeg" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$FFMPEG_ARGS_FILE"
EOF
chmod 0755 "$ffmpeg_dir/bin/ffmpeg"
printf 'stale manifest\n' > "$ffmpeg_dir/output/index.m3u8"
printf 'stale manifest\n' > "$ffmpeg_dir/output/audio.m3u8"
printf 'stale init\n' > "$ffmpeg_dir/output/audio-init.mp4"
printf 'stale segment\n' > "$ffmpeg_dir/output/audio-1.m4s"

OUTPUT_DIR="$ffmpeg_dir/output"
FFMPEG_ARGS_FILE="$ffmpeg_dir/arguments"
PATH="$ffmpeg_dir/bin:$PATH"
export OUTPUT_DIR FFMPEG_ARGS_FILE PATH

sh "$repo_dir/scripts/run-ffmpeg.sh" -hls_start_number_source epoch
[ ! -e "$ffmpeg_dir/output/index.m3u8" ]
[ ! -e "$ffmpeg_dir/output/audio.m3u8" ]
[ ! -e "$ffmpeg_dir/output/audio-init.mp4" ]
[ ! -e "$ffmpeg_dir/output/audio-1.m4s" ]
grep -q '^-hls_start_number_source$' "$FFMPEG_ARGS_FILE"
grep -q '^epoch$' "$FFMPEG_ARGS_FILE"

echo 'script tests passed'
