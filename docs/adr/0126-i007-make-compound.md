# ADR 0126 — I-007 MakeCompound persist with external-link include-or-unlink

## Status

Accepted for Increment 2.27 as a follow-up persist slice of I-007. I-007 stays partial. I-006 remainingScope (track lock / syncLock / link/unlink / multi-track bounds, and field-aware invert of Slip / Roll / Slide) is not closed. Optical-flow interpolation, reverse, freeze, and smooth curves stay unclaimed. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`.

## Decision

`MakeCompound` creates a child sequence, rebases selected item starts by the selection's bounding start, fills interior holes with explicit Gaps, and replaces the parent interval with a nest clip (`source.kind=sequence`, pinned version, `streamId` null). Neighbor clips outside the interval stay on the parent.

An AV link that has members outside the selection is `COMPOUND_EXTERNAL_LINK` and does not half-write. The caller must `UnlinkAudioVideo` first or include every member. Including a complete pair moves both into the child, keeps the existing group there, and links the parent nest pair with `syncPolicy=preserve`. This does not silently mark `allowOutOfSync`. A locked participating track is `FIELD_LOCKED`. Depth greater than 8 is `NEST_DEPTH`. Cycles stay fail-closed. Local writing admission now accepts official root-plus-child nest documents; Project `user_version` is unchanged.

UpgradeNest, OpenNested, and P2 reverse/freeze/smooth are not opened.

## Consequences

I-007 remains partial. Official new suite: 5 tests. Frozen 2.24 retime/nest (8), ignore-links move (6), and unlink invert (5) suites were re-run, not rewritten. Analyzer exit 0. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i007-make-compound/`.

## Follow-up

UpgradeNest duration-change fit/trim/ripple, OpenNested, V-003 playback, and I-006 remainingScope stay open. Next honest Linux/Web increments include leftover I-027 remainingAcceptance (tool-call pairing, fork/resume HTTP, deleting a body leaves no searchable copy).
