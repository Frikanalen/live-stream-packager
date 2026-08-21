# Live stream packager Helm chart

This chart receives an MPEG-TS stream, transcodes two H.264 renditions plus
AAC audio with FFmpeg, packages DASH and HLS with Shaka Packager, and serves
the result with Nginx. The HLS master playlist is available at
`/stream/index.m3u8` when the default ingress is enabled.

## Pipeline

```text
UDP source -> Cubemap -> HTTP MPEG-TS -> FFmpeg -> local UDP -> Shaka -> Nginx
```

Cubemap is enabled by default and exposes UDP port `5004` on its configured
LoadBalancer IP. It keeps ingest separate from the transcoder pod so a normal
packager rollout does not require the source to reconnect. Set
`cubemap.enabled=false` and `ffmpeg.inputSourceUrl` to use a direct FFmpeg
input instead.

The HLS output is pod-local. The chart therefore enforces one replica and uses
a `Recreate` Deployment strategy. Scaling it requires shared origin storage or
request routing that guarantees a playlist and all of its segments come from
the same origin generation.

## Failure recovery

The pipeline treats lack of media progress as a failure:

- FFmpeg has a bounded network read timeout and exits if Cubemap stops
  returning bytes.
- Shaka's UDP inputs time out when FFmpeg stops producing packets.
- Cubemap readiness tracks incoming UDP datagrams. Its UDP Service publishes
  not-ready addresses so a returning source can restore readiness; only its
  HTTP consumer Service is withdrawn while input is stale.
- FFmpeg and Shaka liveness probes require the media playlist's last segment
  to advance, and readiness verifies that the referenced segment exists and
  is non-empty.
- A Packager restart removes stale manifests before startup checks run. Media
  sequence and segment numbers are derived from wall-clock time so they never
  reset to zero across restarts.

If the public endpoint is unavailable, check ingest before restarting the
packager:

```sh
ssh -tA frikanalen.no ssh dev-kube-1 \
  kubectl get pods,svc,endpoints -n default \
  -l app.kubernetes.io/name=live-stream-packager
```

After UDP delivery is restored, a complete pipeline restart can be requested
with:

```sh
ssh -tA frikanalen.no ssh dev-kube-1 \
  kubectl rollout restart deployment/stream-live-stream-packager
```

## Monitoring

The Kubernetes readiness state is suitable for alerting and the public
manifest is suitable for a black-box probe. At minimum, monitor:

- Cubemap and packager pod readiness.
- Container restart-count increases.
- Age and advancement of `audio.m3u8`.
- HTTP success for `/stream/index.m3u8` and one referenced media segment.
- UDP receive rate on the Cubemap pod or LoadBalancer.

A `200` response for only the master playlist is not a sufficient health
check: the master is mostly static and can outlive the media pipeline.

## Configuration notes

- FFmpeg and Shaka arguments are YAML arrays so every argument is passed
  verbatim rather than reparsed by a shell.
- Image values accept either `tag` or `digest`; `digest` takes precedence.
- Cubemap is pinned to the known-good deployed digest. Update that digest
  deliberately when rebuilding `docker/cubemap`.
- `storage.sizeLimit`, resource requests, and resource limits bound the
  otherwise pod-local live window.
- `nodeSelector`, `affinity`, and `tolerations` apply to both Deployments.

See `values.yaml` for all options.

## Development and releases

Run the same validation as CI with:

```sh
helm lint --strict .
helm template stream . --namespace default
sh tests/scripts-test.sh
```

Release Please maintains `CHANGELOG.md`, `Chart.yaml`, tags, and GitHub
releases from Conventional Commit messages. When a release PR is merged, the
release workflow publishes the chart to
`oci://ghcr.io/frikanalen/charts/live-stream-packager`.
