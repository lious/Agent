# ADR0009 — bounded offline PCM→AudioBus→AAC export (v1.5)

Status: implemented Linux development slice; original I-023/I-024/V-002 remain
PARTIAL. No original104 snapshots or acceptance criteria are replaced.

## Why this increment

The previous silent-video user path lacked actual audio execution. Browser positive
WebRTC is objectively blocked by managed zero-host-ICE policy. We leave that
qualification nonzero and its policy untouched, and implement unblocked original
media work. Flutter/Dart remains the shared UI/domain/Harness; C++ FFmpeg remains
the native codec adapter. Python is acceptance orchestration, never a media engine.

## Decisions and real user path

Import an audio-bearing video with explicit **video clip only** acknowledgement;
source bytes/audio metadata remain in the local verified CAS. Edit/split/trim/undo
video, persist master gain/mute/pan/solo through original revision/CAS/undo/storage,
save/archive/restore/reopen; opt in **for this export** to selected video clips’
embedded source audio. Real libavcodec + libswresample decode48k interleaved float,
original Dart AudioBus does DSP in1024frame blocks, native AAC LC48k stereo is
interleaved with Main4 H264 into the existing verified/atomic MP4 publication path.
Concurrent edits do not alter the frozen export snapshot; concurrent exports on
one workspace reject EXPORT_BUSY. Cancellation never publishes a staged result.

**Explicit deviation/additive temporary mode, NOT a silent redesign:** source
embedded audio export is NOT a persisted AudioClip/link group, automatic linked
edit propagation or an audio-only import/editor. No complete timeline RenderGraph,
track/device playback, effects/duck automation, AudioSink ring or presentation clock
is claimed. Full original contracts remain tracked with their dependencies. A future
AudioClip implementation must preserve this opt-in behavior via an explicit migration
or compatibility path, never reinterpret a saved video-only clip as a linked clip.

## Bounds and integrity

- Development adapter only: existing qualified SDR Rec709 limited8bit CFR1× video;
  Main4 macroblock/frame + macroblock/s +20Mbps maxrate/25Mbit CPB gates; no hardware,
  HDR/VFR export, arbitrary scaling/effects or unqualified codec fallback.
- Audio1..120s48k stereo,<=128 ordered/nonoverlapping regions; one decoded region
  and one mixed file,1024frame DSP blocks, native decode<=600s history/2Mpackets/
  bounded conversion block. Long source seeks beyond that bound explicitly fail,
  not silently truncate or allocate unbounded memory. Region gaps outside declared
  source duration are silence; missing decoded coverage INSIDE it is AUDIO_TRUNCATED.
- Mono/stereo only; unspecified WAV1/2channel layouts map to standard mono/stereo,
  never infer surround. PCM WAV has documented zero origin when no container start
  timestamp exists. Otherwise unknown timestamps, format changes, discontinuities,
  unsupported channel/rate/codec and nonfinite PCM fail explicitly.
- Rational source/timeline origins remain domain Q values; absolute48k boundaries
  use ties-even rather than accumulating rounded clip lengths. SWR drains with null
  input; AAC’s actual initial_padding/packet duration/skip metadata is preserved.
  No guessed1024/896 sample trimming or submitted-sample playback clock.
- NEW private PCM files, native O_EXCL/O_NOFOLLOW/0600; bounded private temp dir,
  original CAS/hash/output capability gates, cleanup on every failure/cancel.
  These internal local-path APIs are NOT peer endpoints. No material is uploaded.
- Verifier probes codec/profile/level/format/duration, decodes logical AAC content,
  checks original video duration/hash and only then atomically publishes. Real
  independent60s pulse/flash/DTS qualification supplements—not replaces—this verifier.

## Evidence and unfinished acceptance

`tools/acceptance/run_audio_qualification.py` runs synthetic60s1080p30 actual SDK
export while changing the project revision, then independent ffprobe packet timing,
1800 decoded video frames and60 decoded audio pulse onsets. PCM44.1k impulse length,
peak position/trim, gain/mute/no-op/undo/reopen, malformed layout/PTS/NaN, busy and
cancel are separate actual tests.10 AAC cancellations wait for actual submitted
encoder progress; the diagnostic explicitly is NOT presented device time.

See `docs/implementation/evidence/audio-aac/summary.json` for measured results,
commands, versions and failures. No P0 physical hardware/AudioSink clocks/device
switch, non-Linux platforms, cross-physical-device collaboration, full original
Schema/RenderGraph/proxy or full release/legal SBOM qualification is asserted.
System SQLite3.46.1 remains rejected; approved3.54.1 gate and real v4/v5/v6→v7
migrations, quarantine/lease/fence/permissions/save/restore regressions remain.

Official resampler reference opened during implementation:
https://ffmpeg.org/doxygen/7.1/group__lswr.html . Runtime codec configuration/license
facts are recorded; GPL-enabled system libx264 is a redistribution/legal review
constraint, NOT inferred permission to distribute a production binary.
