# ADR0031 — Physical timeline capture and latest-native-ghost release

Status: implemented bounded native subset (Increment1.24); original I-005 remains partial.

## Contract
Read immutable `docs/studio/spec/s3.md` selection/snap/drag row and original I-005 work item. Keep original hard dependency I-003, each-operation positives/negatives and1000 randomized NLE undo acceptance. No snapshot/acceptance rewrite, no persistence schema/registry.

## Interaction and coordinates
Workbench now paints real sequence clips/tracks/rational time ruler; ordinary click selects and Shift-click toggles. Dragging an already selected/implicitly linked member preserves the selection closure. Horizontal drag arbitration starts the SDK candidate at frozen project hash/revision/writer. All members are validated, including hidden linked audio and paired dissolve endpoints; same-track/reject/includeLinks=true only.

Flutter global positions are transformed by actual RenderBoxes into **scrolled content logical pixels**. Capture the original grab coordinate, not the clip origin; earliest-video reference plus measured displacement feeds existing `planMoveSnap`. Scroll offset is already included by Flutter transforms, never added a second time. UI measurement alone rounds to1e-6 logical px; zoom is an integer logical px/s slider. All downstream time/snap/grid math remains Q. No device-pixel/wall-clock substitution. Pointer playhead is explicitly0s (viewport editing target, not AudioSink time); existing numeric panel remains available separately.

Horizontal scrollbar/wheel pans a bounded three-screen canvas (max20,000 logical px); optional project-frame window origin reaches distant content without proportional-to-duration allocation. Zoom/pan changes cancel capture. No edge-autoscroll/cross-track drop, thumbnail/GPU/performance/full mobile qualification is claimed. Leaving the captured row or viewport cancels rather than silently clamping or reinterpreting the drop.

## Atomicity, preemption and async resources
Only an accepted horizontal recognizer plus matching physical pointer UP AND recognizer END may release. Tap, identity/rounded-zero delta, Escape, OS cancel, second pointer/pan-zoom, wheel/horizontal/ancestor scroll, focus loss/inactive lifecycle or viewport/row exit never commit. A final UP re-evaluates its actual coordinate; a stale prior MOVE is insufficient. No candidate retry/nearest-valid fallback on lock/collision/negative/mixed-grid/handles failures. Other workbench mutations/playback are excluded while capture/release validation is active.

Metadata candidates update synchronously. A single native preview waiter plus latest-dirty flag bounds work; gesture identity, candidate generation and document hash fence late images. Clear the preceding image on EVERY candidate, including failures. Release waits for the latest actual native ghost rather than publishing an older image; preview/decode timeout/failure cancels, SQL failure closes capture, no automatic CAS retry. Timers/waiters cancel on disposal/preemption and late ui.Images are disposed. Current-source/caption/opaque admission rules remain strict, including marker-bearing projects. The original SDK transaction remains the only persistence/undo boundary.

## Measured adjacent export defect
A legal pointer displacement96px at100px/s quantizes to29/30s, extending a3s linked fixture to119/30s. Existing AAC verification correctly rejected the MP4: stream edit-list duration190368 samples vs requested190400 (32 samples lost). FFmpeg's default1000Hz movie clock truncated the fractional edit duration. Configure the existing MP4 muxer with checked `LCM(fps.num,48000)` movie_timescale (int32 bound; explicit refusal if unrepresentable). Do NOT change sample count, add silence, loosen verification or round content. Independent91/119-frame regressions check exact sample counts and shared preencoder pixels. This is not the unrelated AudioSink startup/resume underrun fix.

## Verification / remaining scope
Frozen-source commands, early failures and final outcomes: `docs/implementation/evidence/pointer-drag/summary.json`. Three actual review/correction rounds: REVIEW.md1.24. Linux CPU SDR consumer only, no physical AV/GPU/other platform promise. Full clipboard/group/insert-overwrite/cross-track/mobile gesture matrix, marker editor, balanced interval index, field-aware inverse, O(n) history cost and full1000 randomized NLE qualification remain unfinished. Old-writer schema9 limitation and historical underrun failures remain; RTC policy unchanged. Local commit only; no push or remote diagnosis.
