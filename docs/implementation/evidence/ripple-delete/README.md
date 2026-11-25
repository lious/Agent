# Evidence — Increment 1.28 ripple delete of a single continuous range

Frozen selected tests for RippleDeleteClips on one continuous range R. Lift/leave-gap, reject, overwrite and insert stay distinct. Ripple trim and closing a move source hole are not opened. Same-project, existing tracks only.

- Aggregate source SHA256: `cf47f9fd9553ce3f8b2addeff762d2de516d45a30553670fa4f1e913544f20e2`
- Parent commit: `3e73ab572a43201a73a57c5fe9cc600947492647`
- Selected Dart/Flutter cases: 64 passed, 0 failed, 0 skipped (document 34 = ripple-delete 9 + insert 10 + overwrite 8 + clipboard 3 + multi-move 4; SDK 24 = ripple-delete 3 + insert 3 + overwrite 2 + clipboard 3 + multi-move 8 + snap 5; UI 6 = ripple-delete 1 + insert 1 + overwrite 1 + clipboard 1 + multi-move 1 + snap 1). The previous insert 51, overwrite 37, clipboard-only 7, and pointer-drag 281 are not included or reused.
- Additional regressions (exit 0, not mixed into the 64): flutter analyze; verify_definition_history (old library); verify_command_history (SIGKILL around undo/redo); opacity_cancel 100.

See `summary.json`, ADR0035 and `docs/implementation/REVIEW.md` Increment1.28. I-005 remains partial.
