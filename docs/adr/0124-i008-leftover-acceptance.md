# ADR 0124 — I-008 leftover handles, boundary continuity, and atomic undo

## Status

Accepted for Increment 2.25 as official coverage of the three leftover I-008 remainingAcceptance items. I-008 stays partial. `fullTaskComplete` stays 0. V-003 is not claimed. No new unregistered effect plugin is introduced. I-008 remainingScope (unregistered plugins, advanced color) is not closed.

## Decision

Missing transition handles stay refuse-closed with no freeze fallback and no document change: dissolve uses the existing `TRANSITION_HANDLE_MISSING` code; luma wipe uses `HANDLE_UNAVAILABLE`. Existing codes are not retargeted. A clip that already carries a registered transform2d@1.0.0 curve still cannot steal missing dissolve handles.

Registered transform2d@1.0.0 linear keys stay continuous at shared knots. A split inserts matching values on both remnants at the cut. A trim interpolates the new boundary rather than jumping.

`TransformKeyframeProposal` coalesces continuous drag samples of one key into a single commit. InversePatch kind stays `restoreSnapshot`. One undo restores the before content hash (a new revision of that snapshot, not a replay of the samples, and not one history node per pointer move). Cancel writes nothing. A later staged refusal does not half-write.

Frozen 2.05 / dissolve / luma official suites are not rewritten.

## Consequences

I-008 remains partial. Official new suite: 4 tests. Frozen transform2d keyframe (6), dissolve (4), and luma wipe (6) suites were re-run. Analyzer exit 0. 87-task counts stay 0 complete / 36 partial / 38 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i008-leftover-acceptance/`.

## Follow-up

V-003 GPU/real-render consistency remains a gate. Unregistered plugins and advanced color stay closed. Field-aware invert matrix rows for SetTransformKeyframe / RemoveTransformKeyframe are still not opened; linear undo stays tip snapshot restore. Next honest Linux/Web increments include I-029 intent/forgetting watermarks, or a follow-up I-007 MakeCompound persist that first handles I-006 external-link inclusion / unlink.
