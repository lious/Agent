# Evidence — Increment 1.27 insert paste and move

Frozen selected tests for collision mode=insert on PasteClips and MoveClips. Reject and overwrite remain distinct. Ripple-delete/trim and ripple-close of a move source are not opened. Same-project, existing same-kind tracks only.

- Aggregate source SHA256: `bddacaeb9855e663309d169d938269d292ddc737a2eea64dddf4c10cebf571cf`
- Parent commit: `5602bb28425ea6270f772b3bda79cba86048cb15`
- Selected Dart/Flutter cases: 51 passed, 0 failed, 0 skipped (document 25 = insert 10 + overwrite 8 + clipboard 3 + multi-move 4; SDK 21 = insert 3 + overwrite 2 + clipboard 3 + multi-move 8 + snap 5; UI 5 = insert 1 + overwrite 1 + clipboard 1 + multi-move 1 + snap 1). Pointer-drag 281, the previous clipboard-only 7, and the previous overwrite 37 are not included or reused.
- Additional regressions (exit 0, not mixed into the 51): flutter analyze; verify_definition_history (old library); verify_command_history (SIGKILL around undo/redo); opacity_cancel 100.

See `summary.json`, ADR0034 and `docs/implementation/REVIEW.md` Increment1.27. I-005 remains partial.
