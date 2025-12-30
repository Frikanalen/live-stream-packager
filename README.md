# Live stream packager Helm chart

This helm package offers a ready-to-use HLS stream on /stream/index.m3u8.

By default, it will use cubemap to reflect the UDP stream coming from our Cisco
D9036 encoders. cubemap.loadBalancerIp must be set to an available LoadBalancer
IP address. Then, ffmpeg re-codes it to the various profiles as specified in
ffmpeg.encodingOptions in values.yaml.

It can optionally be configured to pull a stream directly with ffmpeg, in which
case cubemap CRDs will not be generated.  To do this, set ffmpeg.inputSourceUrl
and cubemap.enabled: false

See `values.yaml` for all configuration options.
