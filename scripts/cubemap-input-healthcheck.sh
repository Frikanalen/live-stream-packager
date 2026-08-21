#!/bin/sh
set -eu

max_age=${CUBEMAP_INPUT_MAX_AGE_SECONDS:?CUBEMAP_INPUT_MAX_AGE_SECONDS is required}
state=${CUBEMAP_HEALTH_STATE_PATH:-/tmp/cubemap-input-health.state}
now=$(date +%s)
snmp_file=${CUBEMAP_SNMP_FILE:-/proc/net/snmp}
current=$(awk '/^Udp: / { seen++; if (seen == 2) print $2 }' "$snmp_file")
[ -n "$current" ] || exit 1

if [ ! -f "$state" ]; then
  printf '%s 0\n' "$current" > "$state"
  exit 1
fi

previous=0
changed_at=0
read -r previous changed_at < "$state" || true

if [ "$current" -ne "$previous" ]; then
  printf '%s %s\n' "$current" "$now" > "$state"
  exit 0
fi

[ "$changed_at" -gt 0 ] && [ $((now - changed_at)) -lt "$max_age" ]
