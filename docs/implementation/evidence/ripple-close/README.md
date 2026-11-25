# Evidence — Increment 1.30 ripple close range (vacated move source)

Frozen selected tests for RippleDeleteClips with an explicit continuous TimeRange, including closing a vacated insert-move source hole as one persistent command. Insert-mode MoveClips is unchanged and still leaves the source as a gap; no new move mode is added. Clip-id ripple delete, leave-gap delete/trim, shorten-only ripple trim, and reject/overwrite/insert stay distinct. Ripple-trim lengthening, auto-close-on-move, new-track and cross-project remain closed. Same-project, existing tracks only.

- Aggregate source SHA256: `55d1215cda9c6ff810f825df60e25564dbe8d90e4eb8113ddffb9d3871e46340`
- Parent commit: `83cc5951083b4090cc27a25a9a46781fedb693b1`
- Selected Dart/Flutter cases: 85 passed, 0 failed, 0 skipped (document 47 = ripple-close 6 + ripple-trim 7 + ripple-delete 9 + insert 10 + overwrite 8 + clipboard 3 + multi-move 4; SDK 30 = ripple-close 3 + ripple-trim 3 + ripple-delete 3 + insert 3 + overwrite 2 + clipboard 3 + multi-move 8 + snap 5; UI 8 = ripple-close 1 + ripple-trim 1 + ripple-delete 1 + insert 1 + overwrite 1 + clipboard 1 + multi-move 1 + snap 1). The previous ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7, and pointer-drag 281 are not included or reused.
- Additional regressions (exit 0, not mixed into the 85): flutter analyze; verify_definition_history (old library); verify_command_history (SIGKILL around undo/redo); opacity_cancel 100.

See `summary.json`, ADR0037 and `docs/implementation/REVIEW.md` Increment1.30. I-005 remains partial.
