# ADR 0201 — Official s3 preview clamp and no silent AI correction (I-005 leftover)

## Status

Accepted for Increment 3.02 as a distinct already-specified s3 leftover on I-005: a preview drag may clamp in real time, but a final command must submit the clamped exact parameters and the user must see them; an AI call defaults to refusal rather than silent correction; an unclamped out-of-range final command does not write. I-005 stays partial and is not marked complete. Remaining I-005 remainingAcceptance labels are not silently cleared. A TrimPlanner, new trim modes, and a Flutter widget tree are not invented. Video/caption muted/solo, OS clipboard, auto-close, and mobile gestures stay closed. Increment 2.82 0.02s link-offset work and the frozen s3 1/30s suite are not re-qualified and are not rewritten. Increments 2.74–3.01 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s3 states that `SOURCE_OUT_OF_RANGE`, `TRANSITION_HANDLE_SHORT`, `COLLISION`, and `SYNC_LOCKED` leave the command unwritten, that a UI drag may clamp in real time for preview, that the final command must submit the clamped exact parameters and let the user see them, and that an AI call defaults to refusal rather than silent correction.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_command_clamp_probe/lib/command_clamp_admission.dart`:

- A non-final preview drag may clamp and does not write (`wrote=false`).
- A final command that submits clamped exact parameters the user has seen is admitted (`wrote=true`).
- An unclamped out-of-range final command does not write and is refused with the official bound code (`SOURCE_OUT_OF_RANGE`, `TRANSITION_HANDLE_SHORT`, `COLLISION`, or `SYNC_LOCKED`).
- Clamped parameters that are not visible to the user are `CLAMPED_PARAMETERS_NOT_VISIBLE`.
- An AI call that is out of range, or any silent correction, is `SILENT_CORRECTION_FORBIDDEN`.
- This does not invent a ghost widget, a TrimPlanner, or new trim modes, and does not rewrite existing edit-algebra `SOURCE_OUT_OF_RANGE` consumers.
- `trimPlannerInvented`, `videoMutedSoloOpened`, `osClipboardInvented`, `autoCloseInvented`, `mobileGesturesInvented`, `flutterWidgetTreeInvented`, `linkOffsetRequalified`, `frozenS3SuiteRewritten`, and `newTrimModesInvented` stay false.

`tools/spikes/command_clamp/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s3 preview-clamp and no-silent-correction bound is officialized at this admission. Other I-005 remainingAcceptance labels stay listed and are not silently cleared, so I-005 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i005-command-clamp/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this command-clamp admission, Increment 2.82 0.02s link-offset work, or the frozen s3 1/30s suite. Do not invent a TrimPlanner or a Flutter widget tree, and do not silently clear remaining I-005 remainingAcceptance labels.
