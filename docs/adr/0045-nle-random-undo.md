# ADR 0045 — Qualify opened I-005 commands with 1000 seeded random undo

## Status

Accepted for Increment 1.38 as the original I-005 remainingAcceptance item “1千随机序列undo后文档hash相等”, limited to already-opened commands. I-005 and I-010 remain partial.

## Decision

A seeded random driver walks already-opened NLE commands (reject/overwrite/insert MoveClips, includeLinks true/false, ripple delete/close/trim, SetCaptions, SetMarkers). It does not invent a new MoveClips mode, does not auto-close a vacated source, and does not open I-006, new tracks, cross-project bake, OS clipboard, field-aware InversePatch, source-interval crop, or MP4 burn-in.

At the document algebra, each applyEdit is a pure function: the before document’s content hash is unchanged after success or refusal. A locked host or a negative timeline start refuses the whole group and leaves captions and markers in place. Source-anchored cues are never silently dropped. After 1000 seeded trials of short random sequences, walking the immutable snapshots returns to the start hash.

At the workspace journal, 1000 seeded mutating NLE edits followed by 1000 undos restore the start content hash (revision excluded). Redo restores the post-edit hash. A short real path covers one persistent command, undo/redo, archive fork, sidecar export, and the existing preview/export refusal of caption and marker burn-in.

## Consequences

This increment adds no new edit command and no new persistence table. It qualifies the already-delivered leave-gap, ripple, collision, caption (default clipLocal / follow / interval / source-window), and marker (absolute default / clipLocal follow / ripple interval) semantics under random sequences. The original section-3 full positive/negative matrix, field-aware inverse, auto-close-on-move, and I-006 remain unfinished.

## Evidence

`docs/implementation/evidence/nle-random-undo/`.
