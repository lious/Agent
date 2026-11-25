# ADR0010 — Persistent AV clips and broader Project2 semantic closure

- Status: implemented restricted Linux local slice; original task acceptance unchanged.
- Increment:1.6.0; baseline `c0dbbb951893c32e60f9e7d8b89f59e1f48bafdf`.
- Original contracts: `docs/studio/spec/s2.md`, `s3.md`, `s5.md`, tasks I-002/I-003/I-006/I-009/I-023/I-024. Original104 exports are untouched.

## Decision

Audio and video are **separate existing generic Clip objects**, on audio/video tracks, not a new AudioClip JSON entity or root property. `ExtractAudioClip` selects one actual pinned original audio stream, creates an audio track/clip and reciprocal two-member `LinkGroup(syncPolicy:preserve)`. Absolute original stream PTS origins are reconciled before storing source-relative ranges. Audio timeline boundaries use absolute48k ties-to-even quantization; the stored group offsets are the actual member-start minus anchor-start, not assumed zero.

`LinkAudioVideo`, `UnlinkAudioVideo`, `SetAudioTrackState` and linked split/move/non-ripple trim/slip/delete use the original edit/revision/CAS/receipt/undo/immutable-version/SQLite transaction path. Unlink never deletes either clip. Every linked partner's track/field locks are checked; source/grid/collision failures reject the detached transaction, never a half edit. Reused right-hand IDs after undo allocate a new immutable version, including **unlinked audio** splits. Import/append remains supported after extraction.

Persisted audio clips export AAC **by default**, through the existing real native PCM/SWR→Dart AudioBus→AAC/mux path. Per-track mute is persisted. The previous transient embedded-source-audio switch remains available only for projects without persistent audio clips; requesting both refuses `AUDIO_SOURCE_MODE_AMBIGUOUS`, avoiding duplicate mixing. The renderer compiles an audio clip from its own selected stream/source range/absolute sample destinations; it does not infer audio from video metadata. Muting all persistent audio creates actual silence, not an invalid missing-audio error.

The actual Linux editor exposes extraction, linked edits, unlink and track mute. With an audio track, trim/delete are explicitly labelled **leave gap** and execute non-ripple commands. Previously always invoking ripple would fail the new user path; no silent unsupported ripple implementation was substituted. Archive/fork and default-AAC export are exercised with actual UI clicks/codecs, not only SDK ports.

## Schema interpretation and preservation

Project2 remains closed and unmodified. Supplemental pure-Dart semantic checks index only declared entities: opaque extension/provider/plugin parameters and EntityRef maps do not allocate IDs. Added checks cover pinned stream/version/range/map endpoints; retained-definition/dependency blob metadata; rights/proxy refs; nested current sequence cycle/depth; reciprocal routes/groups; effect owners/keyframes/mask/font refs; captions/markers; image parents/root/layers/fonts; and story/provenance refs.

A generic `Shot.subjectRefs:EntityRef[]` is not silently narrowed to characters: local declared asset/character/etc references can resolve. Character appearance assets follow the original explicit attach-to-project contract. Nonembedded font license references and external provider/template/job IDs are not invented project FKs. Retained sequence versions are not incorrectly traversed as the current version's graph. Image parent cycle walks and bounded-depth nesting visits avoid repeated graph expansion. Routing-cycle validation is iterative, with a real3000-node reciprocal-graph/cycle test, and numeric version/Q lookalikes inside opaque plugin/provider parameters are preserved.

The rich synthetic fixture demonstrates **structural/domain roundtrip**, not app feature support. Unsupported effects/image/story/plugin projects still fail write admission with no project/definition side effects; their JSON is preserved by ProjectDocument. This is NOT a complete read-only app/import/renderer for every valid Project2 feature. Broader versioned definition registration prepares declared tables only; current narrow write admission remains authoritative.

## Explicit limitations / remaining original acceptance

- One local video track, one audio track, one caption track; same-source rate1 extraction. No independent audio-only import, arbitrary multitrack routing, effects/ducking, linked ripple/roll/slide or universal AV edit support.
- Fractional frame-grid operations that cannot also preserve the audio48k grid are explicitly rejected; no silent drift/rounding redesign. Editing clip times with captions currently refuses until full source/clip-local caption reprojection is implemented.
- Full Schema semantic/resource closure is **not complete**: retained definition bytes and historical graphs require resource admission; full image/story/effect/business semantics and full supported read-only app path remain. No I-002 completion claim.
- Native bounds remain120s/128audio regions/1024-frame DSP blocks/600s decode history. No hardware/VFR/HDR capability promises beyond existing refusal gates.
- Actual AudioSink/ring, presented-sample clock, underrun/pause/device rebind and timeline playback remain unimplemented. The60s pulse/flash test is **offline file synchronization**, not a device/physical listening test or zero-latency claim. The new persisted-clip user path is separately checked on short real media.
- Positive WebRTC remains blocked by the already-recorded managed zero-host-ICE policy. It is deliberately NOT rerun without changed external conditions; no policy/flag/relay/alternate-transport bypass. Ordinary Chrome identity/protocol regressions remain independent.
- No physical multi-device, iOS/Android/macOS/Windows, GPU, model, paid-service or production deployment qualification. Linux widgets/Chrome/same-host processes do not stand in for these.

## Evidence

`docs/implementation/evidence/persistent-audio/summary.json` and underlying exact command reports. Three review/fix rounds and actual initial failures are recorded in `docs/implementation/REVIEW.md`. Original87 and XD10 remain separate; no original criterion/dependency is removed or shortened.
