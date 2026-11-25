# Evidence — Increment 1.29 ripple trim (shorten only)

Frozen selected tests for RippleTrimClip shortening of one clip plus link closure, then closing the vacated tail. Leave-gap trim, video-only TrimClip(ripple:true), ripple delete, reject, overwrite and insert stay distinct. Lengthening and closing a move source hole are not opened. Same-project, existing tracks only.

- Aggregate source SHA256: `4c931a950b6283ae2f09f1227c964ed69a64793eb80fe75dbd243f39d02a2f1d`
- Parent commit: `182e2aa6557218bc8b92f31e86ea2a68cddef405`
- Selected Dart/Flutter cases: 75 passed, 0 failed, 0 skipped (document 41 = ripple-trim 7 + ripple-delete 9 + insert 10 + overwrite 8 + clipboard 3 + multi-move 4; SDK 27 = ripple-trim 3 + ripple-delete 3 + insert 3 + overwrite 2 + clipboard 3 + multi-move 8 + snap 5; UI 7 = ripple-trim 1 + ripple-delete 1 + insert 1 + overwrite 1 + clipboard 1 + multi-move 1 + snap 1). The previous ripple-delete 64, insert 51, overwrite 37, clipboard-only 7, and pointer-drag 281 are not included or reused.
- Additional regressions (exit 0, not mixed into the 75): flutter analyze; verify_definition_history (old library); verify_command_history (SIGKILL around undo/redo); opacity_cancel 100.

See `summary.json`, ADR0036 and `docs/implementation/REVIEW.md` Increment1.29. I-005 remains partial.
