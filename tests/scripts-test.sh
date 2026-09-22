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
printf 'segment one\n' > "$playlist_dir/segment-1.mp4"
cat > "$playlist_dir/audio.m3u8" <<'EOF'
#EXTM3U
#EXT-X-MEDIA-SEQUENCE:1
#EXTINF:2.0,
segment-1.mp4
EOF

PLAYLIST_PATH="$playlist_dir/audio.m3u8"
PLAYLIST_MAX_AGE_SECONDS=30
HEALTH_STATE_PATH="$test_dir/playlist.state"
export PLAYLIST_PATH PLAYLIST_MAX_AGE_SECONDS HEALTH_STATE_PATH

sh "$repo_dir/scripts/playlist-healthcheck.sh" ready
sh "$repo_dir/scripts/playlist-healthcheck.sh" live

printf 'segment-1.mp4 1\n' > "$HEALTH_STATE_PATH"
if sh "$repo_dir/scripts/playlist-healthcheck.sh" live; then
  echo 'unchanged playlist unexpectedly passed liveness' >&2
  exit 1
fi

printf 'segment two\n' > "$playlist_dir/segment-2.mp4"
cat > "$playlist_dir/audio.m3u8" <<'EOF'
#EXTM3U
#EXT-X-MEDIA-SEQUENCE:2
#EXTINF:2.0,
segment-2.mp4
EOF
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
