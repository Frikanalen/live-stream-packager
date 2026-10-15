#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT HUP INT TERM

helm template stream "$repo_dir" \
  --namespace test \
  --set ingress.pathPrefix=/media/ \
  > "$rendered"

grep -Fq 'path: "/media/"' "$rendered"
grep -Fq 'location /media/ {' "$rendered"
grep -Fq 'alias /usr/share/nginx/html/;' "$rendered"
grep -Fq 'location / {' "$rendered"
grep -Fq 'root /usr/share/nginx/html;' "$rendered"

echo 'ingress tests passed'
