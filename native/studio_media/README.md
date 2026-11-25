# Native local-video development adapter

Actual libavformat/libavcodec/libswscale C++20 implementation, not FFmpegKit or a subprocess wrapper.
This CPU-only Linux slice is NOT the full hardware MediaPort, AVIO capability sandbox, audio mixer,
RenderGraph, proxy/cache, or release distribution. See [ADR 0002](../../docs/adr/0002-local-video-vertical-slice.md).

Prerequisites (Debian/Ubuntu development packages; installing is an explicit local setup step):
`libavformat-dev libavcodec-dev libavutil-dev libswscale-dev nlohmann-json3-dev cmake ninja-build g++ pkg-config ffmpeg`.

```sh
cmake -S native/studio_media -B /tmp/studio-media-native -G Ninja
cmake --build /tmp/studio-media-native
ctest --test-dir /tmp/studio-media-native --output-on-failure
```

C ABI responses own UTF-8 strings; caller must sm_string_free exactly once. Opaque handles are namespace
bound. close/cancel invalidates the current epoch, work owns its engine until it unwinds. Per-engine
concurrent operations return RESOURCE_BUSY, never share decode state. Exceptions cannot cross C ABI.
Export only writes a new staging path; caller verifies, publishes atomically, and removes partial stages.
Do not give untrusted model output direct access to this internal local-path interface.

Linux probe used system FFmpeg 7.1.x, libavformat61.7.103/avcodec61.19.101/avutil59.39.100/swscale8.3.100,
GCC14.2, nlohmann3.11.3. Runtime configuration is in capabilities / verification evidence. The system
libx264 configuration is GPL-enabled. No bundled FFmpeg binary or redistribution authorization is supplied.
