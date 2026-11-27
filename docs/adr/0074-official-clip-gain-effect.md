# ADR 0074 — Official persist of manual clip gain Effects and volume keyframes

## Status

Accepted for Increment 2.02 as a bounded slice of the remaining I-009 gain automation contract (§4, §8D, §3 keyframe table). I-009 stays partial. This increment does not open I-007 piecewise remapping or nest, does not start the V-004-gated I-060/V-024 limiter, does not change I-023 clock/queue/timeout/assertion or Pulse startup scheduling, and does not claim I-023 complete. Increment 1.17/1.18 stay open.

## Context

Increment A.1 admitted official bus routing, silent-track exclusion, and analysis ducking as a separate AUTO layer that never rewrites manual points. I-009's title and deliverable still required manual volume points to persist as clip gain Effects, in the §4 order clip gain → pan → track bus, with the same TRACK_LOCKED / MANUAL_LOCKED protection. Official admission still refused any `effectIds` on audio clips, so there was no writable path to store a `type=gain` Effect or sample-quantized keyframes, and trim/split would have cropped any such curve with the opacity helper (`param` rewritten to `value`).

## Decision

Add `SetClipGain`, `SetGainKeyframe`, and `RemoveGainKeyframe` (`kind: setClipGain` / `setGainKeyframe` / `removeGainKeyframe`) as official persist commands, following the existing specialized opacity command pattern rather than a generic SetKeyframe. Official admission accepts at most one `type=gain` Effect on an audio clip (`pluginVersion` 1.0.0, clip owner, no extensions). Limiter and pan Effect types stay refused (`UNSUPPORTED_EDIT_TECHNIQUE`); video clips refuse gain writes. Keyframe times are quantized to the 48 kHz sample grid (`KEYFRAME_NOT_ON_SAMPLE`); values stay in [-96, 12] dB (`AUDIO_PARAMETER_RANGE`). Default 0 dB is a no-op. An animated curve refuses static `SetClipGain` (`ANIMATED_GAIN_REQUIRES_EXPLICIT_KEYFRAME_EDIT`). Keyframe values are absolute dB; when keys exist, mix compilation uses a clip-local envelope and does not also multiply the static `parameters.gainDb`.

`compileOfficialMixInputs` reads the persisted Effect into `PcmInput.gainDb` or `automation` so `mix48k` applies clip gain, then the existing default pan (0), then the track/master bus. `applyOfficialClipAnalysis` plans the already-admitted AUTO duck against that manual envelope and never writes AUTO points into the Effect JSON. A locked audio track refuses analysis with `TRACK_LOCKED`; `lockedFields` of `effects`, `effectIds`, `gain`, or `effects.*` / `effectIds.*` refuse `MANUAL_LOCKED`. User edits on a locked track or those fields refuse `FIELD_LOCKED`. Split, trim, and overwrite crop gain curves with `param` `gainDb` and rebind owners; slip leaves clip-local keys unchanged. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled.

## Consequences

Independent audio import is not opened here: a writable import path would invent missing I-004 surfaces (`AssetRepository` / `RelinkProposal` / `FileToken`) or a second official audio track. Bus Effect/limiter nodes, I-007 PCM remapping/nest, new-track, invert-matrix rows for these commands or for `SetAudioBusRoutes`, caption export, and cross-device/RTC are not opened. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays `restoreSnapshot`. I-023 remains partial. Thin SDK wrappers call `edit()` only; no new media capability is invented.

## Evidence

`docs/implementation/evidence/clip-gain-effect/`.
