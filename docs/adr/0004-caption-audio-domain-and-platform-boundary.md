# ADR 0004 — real caption/audio domain slice and explicit platform boundaries

Status: implemented DEV subset, original I-009/I-010/I-032 still PARTIAL.

## Captions

One plain caption track with root Caption entities and exact rational timeline ranges;
no forced frame quantization. SetCaptions is one real CommandCoordinator/SQLite CAS
transaction, versions are allocated from immutable high-water marks, and sequence
semantic hashes include referenced captions. Empty-caption historical sequence hashes
are unchanged. Undo/reopen/fork/portable archive retain cues and manual fields.

Deterministic overlap policy for this single-track editor: reject overlapping half-open
ranges, sort by (start,id), permit touching cues. Split duplicates text, trim intersects,
manual text/timing ownership blocks automatic replacement/deletion; failed edits roll
back the whole transaction. Source-coordinate mapping is exact for a positive linear
rate, but synchronized project clip/ripple/anchor editing is NOT implemented: video
timing operations with cues fail explicitly. Append uses video-track end, not a
non-frame caption end. Sequence duration is max(video end, caption end), avoiding a
fake off-grid video gap.

SRT/VTT UTF-8 plain text/ms export and static ASS text/centisecond import are actual
parsers/writers. Markup, VTT styles/settings, ASS overrides/styles produce loss warnings,
never execute scripts. Literal markup is escaped for roundtrip. ASS export requires a
font/layout policy and is refused. Rich word/style/speaker/clip-source anchored project
captions remain read-only, not discarded. Blank leading/trailing/double payload lines
and collapsed millisecond quantization are refused on plain sidecar export rather
than silently losing text/time. Full deterministic font fallback/shaping is unfinished.
MP4 export with cues is refused until a qualified subtitle renderer/mux policy exists;
sidecar success never implies video text was rendered.

## Audio

Actual pure-Dart AudioBus DAG validates reciprocal routes, duplicates and cycles in
all components. Gain is 10^(dB/20); mono pan is equal-power, stereo is explicit linear
balance-v1. Bus/track mute and solo route closure are evaluated on real Float32 PCM,
with Float64 intermediates. Clipping reports CLIPPING_RISK, no limiter/normalizer is
silently inserted. Non-finite samples, mismatched sizes, overflow, unsupported layouts,
active unrouted input, >64 buses and oversized scratch blocks are rejected.

GainEnvelope uses exact absolute sample/rational coordinates and explicit hold/linear
interpolation. Source anchors map through the same positive linear rate. Duck proposals
are separate automatic gain layers with min-dB overlap, clipped endpoints, explicit
clip-local manual protection and locked-track/gain rejection; original points are
immutable. Native audio decode/resample/device clock/AAC/export, linked gain edits and
project Effect automation integration are still missing. A 60-second synthetic PCM
buffer count/impulse test is NOT I-023 device-sync or I-024 encoder qualification.

## Platforms and same-session computation

See versioned [multidevice addendum](../addenda/multidevice-v1.md). Existing native SDK
remains an IO/FFI adapter. The new editable Web host depends only on pure core/Harness
and a real browser IndexedDB adapter, with explicit weaker durability/eviction semantics.
It is not a stub export of the native SDK and not a Web SQLite qualification.

The original PlanGraph 1.0 wire format is reused for a strict free/localCandidate
execution subset. SQLite v4 adds durable plans/steps/outbox. Fences and U63 encode as
strings/BigInt, never JS Number. Monotonic high-water marks persist within a coordinator
boot. A stale boot cannot silently take over or reset wall budget. Full coordinator
restart authority, signed pairing/permission revocation, transfer and network transport
remain gated/unimplemented. Current tests are real same-box processes/Chrome, NOT
physical-device interconnection. Do not mount trusted-local APIs as network endpoints.
