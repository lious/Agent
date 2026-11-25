# ADR0030 — exact viewport snapping into existing atomic MoveClips (I-005 subset)

Status: restricted implementation; original87 acceptance/dependencies unchanged.
Authority: original s3 row25 closest/8 logical px/playhead-cut-marker/ID and snap
before frame quantization; rows36/41/45/51/53 link closure, inverse and refusal.

## Model and targets

A pure TimelineViewport maps rational logical pixels <-> rational seconds using
pan origin, logical origin and positive pixels-per-second. No devicePixelRatio,
wall clock or double participates in project time. UI accepts bounded exact
plain decimals (up to6 fractional digits), not NaN/Infinity/scientific notation.
The editing playhead is a viewport frame coordinate, explicitly NOT the native
AudioSink service clock or a wall-clock estimate.

planMoveSnap freezes base content hash INCLUDING project/revision. It expands
existing complete admitted AV links, excludes every moved media clip's edges
(including linked members), and offers stationary MEDIA clip boundaries plus
editing playhead. Derived Gap boundaries are not independent stationary media
cuts; otherwise moving a group would accidentally snap to its own rebuilt Gap.
Marker ranking exists in the generic pure resolver, but marker-bearing documents
continue to fail existing writable admission: no marker editor/render support is
invented or stripped. Caption cue times are not silently made video cut targets.
The plan explicitly displays expanded member/participating track IDs.

All moved start/end edges are considered. Eligible distance <=8 LOGICAL pixels,
closest wins before kind priority playhead/cut/marker, then ordinal target ID.
If target ID also ties, start-before-end, then stable source point ordering is an
additive deterministic tie rule (not a new product interaction). Sorted targets
are compressed by exact time to the best ranked point; binary nearest searches
avoid all-pairs/frame traversal. All inputs including EXCLUDED target streams
are bounded before filtering (400001 targets/400000 moving edges, derived from
the existing admitted track/item limits); no new persistent index or registry.

## Quantization / validation / authority

The reference is earliest moved video START, else earliest moved audio START.
Pointer x -> absolute requested reference time -> raw delta; nearest selected
edge snap adjusts delta once. THEN quantize reference+delta ties-to-even on the
project video-frame grid, or48k sample grid for audio-only movement. Final delta
is shared by every linked member. No independent audio rounding and no search
for a different valid target after a locked/collision/grid/handle refusal.
Mixed29.97/48k frame moves that cannot preserve exact samples refuse; common
lattice moves can pass existing MoveClips validation. A target can have a
NONZERO final residual after frame quantization; UI reports raw/snapped/final
Q deltas, prequant logical distance, final signed residual and target identity.
It never calls a rounded result an exact target hit when it is not.

SDK begin/update bridge checks frozen plan hash, existing gesture identity/base/
revision and writer fence. Stale plan UPDATE invalidates previous valid ghost;
it cannot release an older value. UI planning/number errors likewise block old
candidate commit and dispose old image, not just geometry errors. Metadata guard
precedes snapshot read on the new begin API. Existing repository transaction,
receipt/idempotency/definitions/pins/outbox/history are reused; only final
MoveClips IDs/delta are persisted, not viewport configuration or a rerunnable snap
recipe. Undo/redo restore saved roots, never recompute snap under a new zoom.

## Actual UI and limits

Existing native checkbox multi-move gains an explicit snapping panel: zoom, pan
frame, pointer logical-x and editing playhead frame; preview shows ruler/readout
and REAL shared native candidate pixels, then existing Commit/Cancel/Undo/Redo/
archive/reopen/export. This is numeric viewport positioning + explicit button
confirmation, NOT a completed physical pointer-drag/snap gesture UI. Expansion
state survives list virtualization; these settings are session viewport-only,
not project mutations/persistent saved viewport support. Decorative ruler clips
in exact TIME before zoom multiplication; conversion to double is drawing-only.

No new storage schema, payload registry, cleanup, target-track, insert/overwrite,
clipboard/group, Alt unlink or field-aware inverse. Original balanced interval
index, full operation/random1000 NLE matrix and O(n)-history realtime performance
remain unfinished. CPU/SDR native restrictions, unsupported opaque preservation,
old-writer/underrun/RTC/physical-device limits remain. See implementation/evidence/
snap-move for frozen-source actual tests and preliminary failures. Local-only
commit: no push or new remote diagnosis of commit_refs_rules.
