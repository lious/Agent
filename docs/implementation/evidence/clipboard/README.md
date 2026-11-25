# Evidence — Increment 1.25 internal clipboard / copy-cut-paste / group

Frozen selected tests for the internal session clipboard and selection-group closed loop. Not the OS clipboard. Same-project, existing same-kind tracks, mode=reject only.

- Aggregate source SHA256: `3a36f2b4331f485a5b9a7acdd6912412d311604cefdaf7a9611b0db28434cd76`
- Parent commit: `30a12eca956f2bf47014b12848645cf51d6d9aad`
- Selected Dart/Flutter cases: 7 passed, 0 failed, 0 skipped (document 3 + SDK 3 + UI 1). Pointer-drag 281 is not included or reused.
- Additional regressions (exit 0, not mixed into the 7): flutter analyze; verify_definition_history (old library); verify_command_history (SIGKILL around undo/redo); opacity_cancel 100.

See `summary.json`, ADR0032 and `docs/implementation/REVIEW.md` Increment1.25. I-005 remains partial.
