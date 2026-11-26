# ADR A.1 — Official AudioBus routing, silent exclusion, and analysis gain protection

## Status

Accepted for Increment A.1 as a bounded slice of the original I-009 remaining official mix/bus semantics (§4, §8D). I-009 stays partial. This increment does not open I-007 piecewise remapping or nest, does not start the V-004-gated I-060/V-024 limiter, does not change I-023 clock/queue/timeout/assertion or Pulse startup scheduling, and does not claim I-023 complete. Increment 1.17/1.18 stay open.

## Context

The Dart AudioBus domain already validated a complete graph, planned ducking as a separate AUTO envelope, and mixed mute/solo/gain. Official local admission still allowed only a single master bus, `SetMasterAudio` replaced the entire bus list with that one bus, mix compilation always fed PCM to the master id, bus automation was sampled as if the buffer started at t=0, and there was no official command that applied a *group* of routes so a cycle could never be shown to leave the document unchanged. The I-009 acceptance still listed: bus-route cycles refused; same-cue audio anchors correct after retime; manual volume / locked-track mutations = 0; silent tracks not mixed in.

## Decision

Add `SetAudioBusRoutes` (`kind: setAudioBusRoutes`) as one official persist command that replaces the audio bus graph and optional audio `trackBusIds` as a single group. The intended `AudioBusGraph` is validated first; `AUDIO_ROUTE_CYCLE`, `AUDIO_ROUTE_MISMATCH`, or a locked track's bus retarget (`FIELD_LOCKED`) leaves the document unchanged. Official writable admission now allows a bounded DAG (≤64 buses, no bus `effectIds`) instead of a single empty master; an audio track may route to any bus that reaches master. `SetMasterAudio` updates only the master bus and keeps sibling buses. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled.

`compileOfficialMixInputs` and the existing export/playback segment builders omit muted audio tracks and pass each remaining clip's `busId`. Domain `PcmInput.silent` / `muted` inputs are excluded from `mix48k` and do not fail an otherwise valid mix when unrouted. `AnalysisGainPlayback.apply` plans ducking as a separate AUTO layer and adds it to manual dB at playback time; manual points are never rewritten; `trackLocked` / `gainLocked` refuse the whole application (`TRACK_LOCKED` / `MANUAL_LOCKED`). Mix-time clip automation samples `GainEnvelope.atTimeline` through the already-admitted linear `timeMap`/`rate` only; this slice does not time-stretch PCM.

## Consequences

Independent audio import, bus Effect/limiter nodes, I-007 PCM remapping/nest, new-track (more than one official audio track), official persist of clip gain keyframes as document Effects, invert-matrix rows for `SetAudioBusRoutes`, caption export, and cross-device/RTC are not opened. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays `restoreSnapshot`. I-023 remains partial.

## Evidence

`docs/implementation/evidence/audio-bus-semantics/`.
