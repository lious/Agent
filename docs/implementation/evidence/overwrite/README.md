# Evidence — Increment 1.26 overwrite paste and move

Frozen selected tests for collision mode=overwrite on PasteClips and MoveClips. Insert/ripple is refused. Same-project, existing same-kind tracks only. Not a new-track, cross-project, or OS clipboard promise.

- Aggregate source SHA256: `729979b12744b128ef7fb359a14ecfb05ac221d93e18debcc0f6e17524527f71`
- Parent commit: `3f1068e848d54eaef00be77e7f1414db6880e594`
- Selected Dart/Flutter cases: 37 passed, 0 failed, 0 skipped (document 15 = overwrite 8 + clipboard 3 + multi-move 4; SDK 18 = overwrite 2 + clipboard 3 + multi-move 8 + snap 5; UI 4 = overwrite 1 + clipboard 1 + multi-move 1 + snap 1). Pointer-drag 281 and the previous clipboard-only 7 are not included or reused.
- Additional regressions (exit 0, not mixed into the 37): flutter analyze; verify_definition_history (old library); verify_command_history (SIGKILL around undo/redo); opacity_cancel 100.

See `summary.json`, ADR0033 and `docs/implementation/REVIEW.md` Increment1.26. I-005 remains partial.
