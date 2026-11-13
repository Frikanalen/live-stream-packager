# Changelog

## [0.4.1](https://github.com/Frikanalen/live-stream-packager/compare/v0.4.0...v0.4.1) (2026-11-13)


### Bug Fixes

* keep the stream from wedging under CPU contention, and restart it if it does ([#14](https://github.com/Frikanalen/live-stream-packager/issues/14)) ([d74b069](https://github.com/Frikanalen/live-stream-packager/commit/d74b069eb3f1b60f55b0eb2d1c60c50935fbcdab))

## [0.4.0](https://github.com/Frikanalen/live-stream-packager/compare/v0.3.2...v0.4.0) (2026-11-08)


### Features

* move from frikanalen.no to frikanalen.tv ([#12](https://github.com/Frikanalen/live-stream-packager/issues/12)) ([aeccdf4](https://github.com/Frikanalen/live-stream-packager/commit/aeccdf45e9ea609492b7eba7d73f3f174da4d2eb))

## [0.3.2](https://github.com/Frikanalen/live-stream-packager/compare/v0.3.1...v0.3.2) (2026-10-30)


### Bug Fixes

* check every media playlist in the ffmpeg health probes ([#10](https://github.com/Frikanalen/live-stream-packager/issues/10)) ([8528eb8](https://github.com/Frikanalen/live-stream-packager/commit/8528eb8b08fa6da1e30e4fbc267db411d84c3c0a))

## [0.3.1](https://github.com/Frikanalen/live-stream-packager/compare/v0.3.0...v0.3.1) (2026-10-15)


### Bug Fixes

* serve stream files through ingress prefix ([962801b](https://github.com/Frikanalen/live-stream-packager/commit/962801b866a06c958fbfea098763f1cca141174e))

## [0.3.0](https://github.com/Frikanalen/live-stream-packager/compare/v0.2.2...v0.3.0) (2026-10-14)


### Features

* add multicast group support to cubemap ([e24761a](https://github.com/Frikanalen/live-stream-packager/commit/e24761afa2ef383f32a43501d451b56b91ee5580))

## [0.2.2](https://github.com/Frikanalen/live-stream-packager/compare/v0.2.1...v0.2.2) (2026-10-14)


### Bug Fixes

* use correct delimiter for language ([d4a9323](https://github.com/Frikanalen/live-stream-packager/commit/d4a932352a75c0ac8e7d11c45b58acff3cbb82bc))

## [0.2.1](https://github.com/Frikanalen/live-stream-packager/compare/v0.2.0...v0.2.1) (2026-10-14)


### Bug Fixes

* Correct invalid language in HLS metadata (no -&gt; nor) ([44f5fea](https://github.com/Frikanalen/live-stream-packager/commit/44f5feabe755d80386fc476aa8649c3bbb43f4df))
* route stream through public ingress ([c408be5](https://github.com/Frikanalen/live-stream-packager/commit/c408be50f989e7911103c1fb820f5ba1baa34c4b))

## [0.2.0](https://github.com/Frikanalen/live-stream-packager/compare/v0.1.1...v0.2.0) (2026-08-21)


### Features

* make stream pipeline self-healing ([#1](https://github.com/Frikanalen/live-stream-packager/issues/1)) ([fbb019a](https://github.com/Frikanalen/live-stream-packager/commit/fbb019a4e9f65ad93567ae0e5edf75c3bb08aef6))
