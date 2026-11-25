# Native local-video development adapter

Actual libavformat/libavcodec/libswscale/libswresample C++20 implementation, not FFmpegKit or a subprocess wrapper.
This CPU-only Linux slice is NOT the full hardware MediaPort, AVIO capability sandbox, device AudioSink/presentation clock,
full RenderGraph/timeline playback/proxy, or release distribution. Offline PCM→Dart AudioBus→AAC export is implemented; see [ADR0009](../../docs/adr/0009-bounded-offline-audio-and-aac.md). See [ADR 0002](../../docs/adr/0002-local-video-vertical-slice.md).

Prerequisites (Debian/Ubuntu development packages; installing is an explicit local setup step):
`libavformat-dev libavcodec-dev libavutil-dev libswscale-dev libswresample-dev nlohmann-json3-dev cmake ninja-build g++ pkg-config ffmpeg`.

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

Offline audio: `sm_decode_audio` writes a NEW private48k/stereo float region (<=120s),
standard1/2channel layouts, actual SWR null-input drain, timestamps/finite samples/
coverage gates and bounded600s decode history. Caller runs Dart AudioBus in1024frame
blocks, then includes PCM in the original render recipe. Native AAC LC metadata and
MP4 mux preserve actual priming/packet durations; no guessed sample subtraction.
`sm_encoded_audio_samples` is only a cancellation diagnostic of submitted AAC input,
NEVER a device presentation clock. Per-export explicit source-audio opt-in is NOT
persistent AudioClip/link-group semantics. All original full-task limits remain.

`python3 tools/acceptance/run_audio_qualification.py --native-library /tmp/studio-media-native/libstudio_media.so --report artifacts/audio.json`
executes actual60s1080p30 flash/pulse qualification. Tests may invoke FFmpeg CLI for
synthetic inputs/independent measurements; application execution never shells out.
