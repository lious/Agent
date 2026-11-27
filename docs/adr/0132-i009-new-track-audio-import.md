# ADR 0132 — I-009 audio new-track and independent audio import

## Status

Accepted for Increment 2.33 as a leftover I-009 remainingScope slice. I-009 stays partial. `fullTaskComplete` stays false. Bus Effect, limiter, and I-007 PCM remapping/nest stay unopened. Video muted/solo on `SetTrackState` stay unopened. A TrimPlanner was not invented. InversePatch kind stays `restoreSnapshot`. `fullTasksCompleted` stays 0.

## Decision

s5 already allows `Asset.kind=audio` and generic `addTrack` of an audio `Track`. This increment officializes those surfaces:

- Local admission accepts ready `kind=audio` assets with a single audio stream, no video stream, and no preview proxies. Shared original blobs are not duplicated.
- `AddTrack` may append an empty audio lane with a routed `busId`. A missing bus is `AUDIO_BUS_MISSING`; caption tracks stay `FEATURE_NOT_IMPLEMENTED`. Multiple audio tracks are admitted. `ExtractAudioClip` uses an existing audio lane (targeted, else lowest `order`) instead of requiring `audioTracks.single`.
- `AppendAudioAsset` is the audio counterpart of the existing local `AppendVideoAsset` import: it registers a standalone audio asset and places an unlinked clip on an already-created audio track. It does not extract from a video host, does not invent a bus Effect or PCM stretch, and does not delete source media when that lane is later `removeContents`.
- The Increment 2.32 official refusal suite is retargeted only for the audio `AddTrack` case, which this increment opens. Caption, video muted/solo, and the other 2.32 refusals stay unchanged.

## Consequences

I-009 remains partial. Official new suite: 3 tests. Frozen official mix semantics, clip-gain, persistent-audio, I-005 add-track, and I-006 syncLock bounds suites were re-run; only the one 2.32 audio-AddTrack refusal assertion was retargeted. Analyzer exit 0. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i009-new-track-audio-import/`.

## Follow-up

Bus Effect, limiter, and I-007 PCM remapping/nest stay open. Caption `addTrack`, video muted/solo, TrimPlanner, OS clipboard, and real device/TTS/clone inference stay unclaimed.
