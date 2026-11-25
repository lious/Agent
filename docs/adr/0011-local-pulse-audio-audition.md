# ADR0011 — Linux local-service timeline audio audition (increment1.7)

Status: implemented restricted development slice; **not** original I-023/V-004 completion.
Original104 exports and their acceptance/dependencies are unchanged.

## Decision and user path

Use mature asynchronous **libpulse17.0**, not a custom device API, a mocked sink,
submitted-sample clock, FFmpeg subprocess, or wall-time playback simulation.
The existing Dart SDK freezes the ProjectDocument hash, resolves verified local CAS
sources, checks original stream facts, decodes with the existing native FFmpeg/SWR
adapter, and renders the existing Dart AudioBus into private bounded PCM. The native
engine feeds the real local PulseAudio service from a fixed ring. Both Linux editors
expose extract persistent audio → play/pause → exact48k seek → explicitly rebind
(paused) → resume/stop. Existing linked editing/save/reopen/archive/AAC paths remain.

This is **audio-only, pre-rendered audition**: <=120s, <=128 regions, one admitted
persistent audio track/master bus, supported1x source/media profile. It does not
invent video timeline rendering, streaming DSP, multitrack effects or independent
AudioAsset import. Muted audio tracks render silence. Changes to a project stop the
old frozen audition; playback controls do not mutate a project revision. Background
lifecycle pauses an opened stream and cancels an unfinished preparation. It never
auto-resumes. Preparation retains directory ownership until its native/isolate work
has finished; stop cannot delete a file underneath that work.

## Clock, backpressure and recovery

* `pa_stream_update_timing_info` → `pa_stream_get_time` without
  `PA_STREAM_INTERPOLATE_TIMING`; convert integer service microseconds to48k samples.
  Scheduling/deadlines/staleness use steady time, **not** project position.
* Clock position is bounded by accepted samples but **not generated from them**.
  Pause is reported only after actual cork acknowledgment; confirmed paused samples
  remain stable. Every recreated stream has a fresh epoch and invalid initial clock.
* Request overall latency with documented `PA_STREAM_ADJUST_LATENCY` rather than
  only stream-buffer latency; report actual `pa_stream_get_latency` validity/sign/value.
  Never assume the request equals measured device latency.
* Fixed8192 stereo-float frames; read/write chunks <=1024; at most4 writes/pump;
  negotiated server maxlength <=4096 frames. Refuse oversized negotiated queues.
  Exact-size regular PCM, finite values,120s limit, O_NOFOLLOW/O_NONBLOCK/CLOEXEC;
  FIFO/symlink/nonregular files refuse without blocking or descriptor leaks.
* True underflow before source EOF freezes and invalidates the clock. No silent
  time stretch, skip, automatic restart or counter-based catch-up. Explicit rebind
  resumes from the last **confirmed** position, always paused; uncertain queued tail
  is disclosed, and may replay after explicit recovery. Actual service drain
  acknowledgment, not submission, determines EOF.
* Sink suspension/movement/loss, service loss, stale clock (>500ms), timing startup
  (>5s) and cork acknowledgment (>2s) fail closed. Seek/rebind are explicit clock
  discontinuities/epochs. Invalid seek/sink name/busy replacement preserves the old
  session. Stop/cancel/close disconnect, join and release resources.
* Only a single explicit local Unix Pulse server path is accepted, no autospawn,
  remote server list, network fallback, cloud material or relay. Production uses the
  existing OS-authenticated local service. Test-only anonymous protocol is confined
  to a fresh0700 directory/Unix socket and isolated daemon/session, not app defaults.

## Platform, qualification and license boundary

The original P0 profile says CoreAudio/AAudio/WASAPI/**PipeWire**; this batch verifies
**PulseAudio17 software null sinks and actual monitor capture**, not PipeWire or a
physical sound device. Compatibility of pipewire-pulse is **not** assumed verified.
`pulseServicePlaybackV1` is separate from `deviceAudioClock:false` and
`physicalPresentationVerified:false`. Do not describe monitor RMS as human hearing,
DAC sample accuracy, zero latency,60s presented AV sync, or hardware qualification.

Pulse is optional in CMake, default ON only Linux. OFF builds retain codec ABI and
explicitly refuse `AUDIO_SINK_PLATFORM_UNAVAILABLE`; other platform binaries were not
built here. Dart capability gating refuses unavailable adapters. Web and other
platforms must use separately qualified platform adapters; no native-FFI import was
added to the portable domain/Harness/browser packages.

Official timing references:
- https://freedesktop.org/software/pulseaudio/doxygen/streams.html
- https://freedesktop.org/software/pulseaudio/doxygen/stream_8h.html

libpulse17 dev headers came from the existing official Debian apt repository;
`libpulse-dev` copyright reports LGPL-2.1+. This records observed library facts,
not a complete transitive release SBOM/redistribution approval. Existing FFmpeg/GPL
and release license gates remain. No production deployment or active CI workflow.

## Evidence and incomplete original acceptance

`docs/implementation/evidence/audio-sink/` records actual native service/monitor,
producer SIGSTOP starvation, sink suspension, daemon SIGSTOP clock staleness,
paused explicit recovery, EOF, invalid files, descriptor repeats, real SDK and
clicked Flutter controls/lifecycle, and existing regression gates. Test fixture
creation/capture Python/FFmpeg CLI is qualification-only; production remains
Flutter/Dart + native C++ FFmpeg/libpulse.

I-023 still needs full original upstream routing/link/DSP/RenderGraph and **60s
presented audio/video** sync with qualified device clock. V-004 still needs its
3-video/2-audio,20-seek,20-minute thermal/backpressure/background/device/P0 matrix.
Video rendering/proxy mapping is next. Physical/non-Linux/multi-device tests remain
unverified. Managed positive WebRTC0-host-candidate failure is retained, not rerun or
bypassed. New XD10 remains separate from original87.
