#!/bin/sh
# Keeps the air log a circular buffer: every few minutes, deletes segments
# older than the retention and the hour and day folders they leave empty.
set -eu

airlog_dir=${AIRLOG_DIR:-/airlog}
retention_minutes=$(( ${AIRLOG_RETENTION_DAYS:-7} * 1440 ))
interval=${AIRLOG_JANITOR_INTERVAL_SECONDS:-600}

sweep() {
  find "$airlog_dir" -mindepth 3 -maxdepth 3 -type f -name '*.ts' \
    -mmin "+$retention_minutes" -delete
  find "$airlog_dir" -mindepth 1 -maxdepth 2 -type d -empty -delete
}

if [ "${1:-}" = "once" ]; then
  sweep
  exit 0
fi

while :; do
  sweep || echo "air log sweep failed" >&2
  sleep "$interval"
done
