# ADR 0130 — I-007 OpenNested resolves the pinned child timeline without auto-follow

## Status

Accepted for Increment 2.31 as an I-007 interface slice. I-007 stays partial. This is not an in-child edit surface: `applyEdit` is not opened on the child sequence, and opening does not write a revision. P2 reverse / freeze / smooth, optical-flow interpolation, and V-003 stay unclaimed. InversePatch kind stays `restoreSnapshot`. `fullTasksCompleted` stays 0.

## Decision

`openNested(project, clipId, snapshotBytes:)` enters the child timeline at the nest clip's pinned `source.version` only:

- If the pin matches the live child, the function returns a detached copy of that live sequence (`fromRetainedSource=false`).
- If the pin is historical, the pin must have a `retainedSources` entry of kind `sequence`. The retained definition bytes are supplied by the caller (workspace CAS), must match `definitionBlobHash`, and must be a Project snapshot of the same namespace and project that still contains that exact sequence version. The returned timeline is that retained sequence (`fromRetainedSource=true`), not the live v2 duration.
- Opening does not mutate the project, does not retarget other pins, and does not auto-follow. After `UpgradeNest`, opening the upgraded pin shows the live child.
- A non-nest clip is `CLIP_NOT_FOUND`. A historical pin without bytes is `RESOURCE_BYTES_MISSING`. A bad hash is `BLOB_HASH_MISMATCH`. The document is unchanged on refusal.

This command is a read/resolve interface, not a persist edit, so it does not invent in-child trim/move/ripple algebra.

## Consequences

I-007 remains partial. Official new suite: 4 tests. Frozen UpgradeNest (5), MakeCompound (5), and retime/nest (8) suites were re-run, not rewritten. Analyzer exit 0. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i007-open-nested/`.

## Follow-up

In-child persist edits on the opened timeline stay unopened. P2 reverse/freeze/smooth, optical-flow, and V-003 stay open. Next honest Linux/Web increment: leftover I-006 TrimPlanner surfaces, only as already specified, without silently closing video muted/solo on SetTrackState.
