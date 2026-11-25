# ADR0028 · Explicit gesture ghosts, one durable command (v1)

Status: implemented native SDK slice; Linux opacity UI exercised. Not full I-005.
Original contract: immutable `docs/studio/spec/s3.md` lines5–20,25,38,41–48;
I-005 acceptance/dependencies unchanged. Builds on ADR0027 journal, not new storage.

## Boundaries

`beginGesture(initial, expectedRevision)` captures project snapshot, writer token,
new gesture ID and a closed target. All updates are ABSOLUTE from this immutable
base, not incremental application of the previous ghost. Supported SDK targets:
single-clip move, trim (fixed edge/ripple mode), slip, static opacity, opacity
keyframe VALUE at fixed local Q time/interpolation, transform2d, crop, colorBasic.
Different clips, operation types, trim modes/edges or keyframe coordinates refuse;
unknown/import/resource-adoption operations refuse. No timer-window/history merge,
no command rewriting, no new table/migration/index or fingerprint registry.

Updates use the existing pure edit algebra/admission and native capability gates.
Ephemeral ghost IDs/versions never enter definitions or pins; normal transaction
allocates real IDs/historical max+1 at release. Ghost is NOT a writable saved
snapshot. Commit rechecks current project/revision/writer and history format, then
uses the existing repository edit/receipt with gesture.id as command.id/receiptKey.
There is no separately persisted gestureGroupId protocol. One changed gesture is
one original command, one undo and one redo. Engine no-op preserves redo; known
zero move/trim/slip cancels without issuing a command. UI opacity returning to its
starting value also cancels (including absence of an identity effect).

A rejected update forbids release of an earlier valid candidate until another
explicit valid update. SQL abort retains the ghost without popping history;
manual retry uses the same ID. Revision/fence conflicts are never rebased/retried
silently. Cancel is idempotent on its own handle; close/project switch discards
pending ghosts. Existing autosave saves committed head only; it may still record
an unrelated checkpoint, never the pointer ghost. Crash before release leaves no
gesture command. Cancellation AFTER successful commit is not undo.

## UI / real renderer

Linux native workbench adds static-opacity drag: DOWN captures, MOVE ghosts,
matching physical UP commits. Escape, pointer CANCEL, ancestor-scroll gesture-
arena loss, lifecycle loss, explicit Cancel or target switch discards pending
state. Flutter Slider onChangeEnd can also mean arena cancellation, so it is NOT
alone authority to commit; a matching pointer-UP gate is required. Keyframed clips
keep their dedicated editor, not flattened into static opacity. Existing numeric
Apply remains an accessible discrete alternative; this slider does not claim new
keyboard/semantic-gesture qualification.

A still ghost preview uses the SAME TimelineVideoGraph, exact project/source Q,
registry and original native raster/opacity/dissolve/YUV node as committed preview
and encoding. Only admitted resource-neutral edits can be gestures. One request
plus a latest-value dirty flag bounds UI render work; generations, project/fence
checks and image disposal prevent late canceled/replaced ghosts from appearing.
Errors stay visible beside the active control. Audio playback stops at begin;
this is not live audio scrubbing, GPU qualification or physical AV sync.

## Evidence / remaining original work

`docs/implementation/evidence/gesture-edit/summary.json` records containing local
commit source hashes, actual selected commands/results, legacy/SQL/SIGKILL and
native cancellation regressions. Real UI drag40 is one command/undo, identity tap
and Escape/pointer/arena cancel write no gesture. Eight SDK targets have a bounded
positive/negative slice, not all section3 operations. Actual rich A/V, AudioClip/
link, caption, durable proxy, archive-fork and preview/encoder tests remain.

Still absent: full multi-select/snap/insert/overwrite/clipboard/groups matrix,
time-coordinate keyframe dragging, all timeline drag UIs, field-aware concurrent
inverse, gesture protocols for agents/peers, large-history realtime performance.
Journal O(n) and strict tip/full-root undo remain. Original I-005 stays partial.
No new RTC/platform claim, no remote publication or remote-policy modification.
