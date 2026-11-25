# ADR0032 — Internal session clipboard, cut/paste and selection groups

Status: implemented bounded native subset (Increment 1.25); original I-005 remains partial.

## Contract
Read immutable `docs/studio/spec/s3.md` copy/paste and link/unlink/group rows, `s2.md` SelectionGroup, and original I-005. Keep the original hard dependency on I-003 and the original acceptance: every section-3 positive/negative, 1000 randomized NLE undo with equal document hash, and whole-group refusal for locked members and negative intervals. No snapshot/acceptance rewrite, no new persistence schema or fingerprint registry.

## Clipboard boundary
The clipboard is an internal, session-scoped package (`ClipboardPayload`) hashed into the `PasteClips` command. It is not the operating-system clipboard and not a new SQLite table. Copy is planning-only and does not write the document or journal. Cut builds a validated payload, then commits one `LiftClips`; the session clipboard is updated only after that lift succeeds. Paste embeds the full payload (and `payloadHash`) so journal/replay/undo stay self-contained. The session clipboard is cleared on close, `openDemo`, resource-fork and archive restore. Crossing to a new project identity never silently reuses a stale package (`CROSS_PROJECT_PASTE_NOT_IMPLEMENTED` and `CLIPBOARD_EMPTY`).

## Admitted paste subset (honest bound)
This slice only pastes into the same project, onto existing same-kind tracks, with collision `mode=reject`. The paste origin is the earliest start in the package; members keep relative position, source ranges, time maps, effect curves, proxy/asset version references (no Blob copies), caption-ineligibility, and audio link offsets. All owned IDs, including effect and keyframe IDs, are rebuilt. Empty paste-at uses the current sequence duration; otherwise the workbench snaps decimal seconds. Overwrite, insert/ripple, new-track creation, cross-project import/bake and OS clipboard are not opened. Local admission still allows at most one video + one audio + one caption track, so “copy A+C onto a new track” cannot be executed here. Admitted captions are absolute-time only and stay put; clip-local caption follow remains refused. Marker-bearing projects remain unwritable.

## Grouping vs links
`GroupClips` / `UngroupClips` mutate `SelectionGroup` membership only. Grouping uses explicit IDs and never silently adds AV link partners. Copy, cut and move expand the complete link closure and the complete selection group, or refuse. Stealing a member from another group, grouping fewer than two clips, or leaving membership inconsistent is refused as a whole (`GROUP_ALREADY_MEMBER`, `GROUP_TOO_SMALL`, `GROUP_MEMBERSHIP_MISMATCH`). Identical re-group is a no-op. Fork/archive remaps `selectionGroups`, `selectionGroupId` and `memberClipIds` with every other owned ID.

## Whole-group refusal
Locks, collisions, negative timeline starts, mixed or missing tracks, incomplete transition handles (`TRANSITION_COPY_REQUIRES_BOTH`), and unsupported caption/marker/gap items abort the entire request. No command writes a subset of the closure. Transitions that are fully included shift `cut` by the paste delta, keep handle durations, and follow the destination track map.

## Verification / remaining scope
Frozen-source commands and outcomes: `docs/implementation/evidence/clipboard/summary.json`. Three actual review/correction rounds: REVIEW.md Increment 1.25. Linux CPU SDR consumer only. Full overwrite/insert/new-track/cross-project/OS-clipboard/mobile/marker matrix, 1000 randomized NLE undo, field-aware inverse, interval index and O(n) history remain unfinished. Old-writer schema9 limitation and historical underrun failures remain; RTC policy unchanged. Local commit only; no push or remote diagnosis.
