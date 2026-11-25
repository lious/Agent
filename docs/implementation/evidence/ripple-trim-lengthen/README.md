# Evidence — Increment 1.31 ripple trim lengthen

Frozen selected tests for RippleTrimClip lengthening (and still-supported shortening) of one clip plus link closure. A positive duration change Δ opens space after the old end and shifts later content; a negative Δ still closes the vacated tail. Insert-mode MoveClips is unchanged and still leaves the source as a gap. Leave-gap trim, video-only TrimClip(ripple:true), clip-id and range ripple delete, range close, and reject/overwrite/insert stay distinct. Auto-close-on-move, new-track and cross-project remain closed. Same-project, existing tracks only.

- Aggregate source SHA256: `a73ab0c5bc0145d00bae2feebc7061c4f2d465bee7f43091156835360ecec2d7`
- Parent commit: `92aa29b08d0b26d11086b626d8f2397b1d318b20`
- Selected Dart/Flutter cases: 95 passed, 0 failed, 0 skipped (document 53 = ripple-trim-lengthen 6 + ripple-trim 7 + ripple-close 6 + ripple-delete 9 + insert 10 + overwrite 8 + clipboard 3 + multi-move 4; SDK 33 = ripple-trim-lengthen 3 + ripple-trim 3 + ripple-close 3 + ripple-delete 3 + insert 3 + overwrite 2 + clipboard 3 + multi-move 8 + snap 5; UI 9 = ripple-trim-lengthen 1 + ripple-trim 1 + ripple-close 1 + ripple-delete 1 + insert 1 + overwrite 1 + clipboard 1 + multi-move 1 + snap 1). The previous ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7, and pointer-drag 281 are not included or reused.
- Additional regressions (exit 0, not mixed into the 95): flutter analyze; verify_definition_history (old library); verify_command_history (SIGKILL around undo/redo); opacity_cancel 100.

See `summary.json`, ADR0038 and `docs/implementation/REVIEW.md` Increment1.31. I-005 remains partial.
