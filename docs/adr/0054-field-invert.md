# ADR 0054 — Field-aware invert of a prior command

## Status

Accepted for Increment 1.47 as a bounded slice of the original I-005 remaining work on field-aware inverse (s3 / s5a). I-005 and I-010 remain partial. This increment does not open auto-close as a MoveClips mode, source-interval crop, marker sidecar formats, a command-history browser, or a full invert matrix for every already-opened command.

## Decision

A named `invertCommand` journal entry can invert one prior committed command that is not the undo tip. The write set is computed on the fly from that command's saved `before_ref` / `after_ref` snapshots (content-level field paths, ignoring `version` / `revision` clocks). If every written field still matches the command's after-image, those fields are restored to the before-image and the store reallocates versions of changed entities (including the sequence when captions or markers change). If any written field was later edited, the invert is whole-group `UNDO_CONFLICT` and does not roll the database back; the user may still branch from a historical snapshot. Partial member applies are not admitted.

Linear `undo` / `redo` stay tip-only snapshot restores. Official InversePatch 2.0 `kind` remains `restoreSnapshot`; field awareness is not a new patch kind or table. Invert of the current tip, of `undo` / `redo` / `undoLatest` / `invertCommand`, or of an empty (clocks-only) write set is `UNDO_CONFLICT` — use Undo for the tip. `invertCommand` itself is a normal journal command (it clears redo).

The demonstrated user path adds two left-side captions, moves an uninvolved right remnant (leave-gap, not auto-close), and inverts the later `SetCaptions`: the extra cue is removed, the earlier cue and the moved remnant (and any later markers) stay, then undo/redo, archive/fork, and VTT export work; preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`. Invert after a followed `clipLocal` host move of the same cue is `UNDO_CONFLICT`. Already-delivered LiftClips/Cut, MoveClip, DeleteClip, TrimClip, split/interval/source-window, and marker semantics stay unchanged.

The workbench exposes a compact command-id field and Invert button; it does not list every history row (that would lengthen the scroll and regress `marker-label` hit-testing).

## Consequences

Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006 roll/slip/slide, MP4 burn-in, mid-stack linear undo, and a complete command-by-command invert matrix remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered insert-move leave-gap, explicit-range ripple close, `includeLinks=false`, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only and linked-audio ripple `TrimClip`, caption-aware ripple and leave-gap `DeleteClip`, caption-aware `MoveClip` and `LiftClips`/Cut, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert/`.
