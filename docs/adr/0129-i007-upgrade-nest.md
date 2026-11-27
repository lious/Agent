# ADR 0129 — I-007 UpgradeNest with fit / trim / ripple and no auto-follow

## Status

Accepted for Increment 2.30 as a follow-up persist slice of I-007. I-007 stays partial. OpenNested, P2 reverse / freeze / smooth, optical-flow interpolation, and V-003 stay unclaimed. InversePatch kind stays `restoreSnapshot`. `fullTasksCompleted` stays 0.

## Decision

`UpgradeNest{clipIds,fromVersion,toVersion,lengthPolicy,rippleTrackIds}` retargets selected nest clips from a frozen `fromVersion` to the live child `toVersion`. Other nests that still pin `fromVersion` are not updated.

If the child duration changes, `lengthPolicy` is required:

- `fit` keeps the nest's timeline duration and recomputes a linear `timeMap.rate` so the full new child plays in the old slot (`rate * timelineDuration = sourceDuration`).
- `trim` keeps rate 1, uses `min(old, new)` as the source and timeline duration, and leaves an explicit gap when the child is shorter (later clips do not move).
- `ripple` sets the nest duration to the new child duration and shifts later clips on the explicit `rippleTrackIds` union the target tracks. The list is not auto-expanded to other `syncLock` tracks. `rippleTrackIds` on fit/trim is `RIPPLE_TRACKS_REQUIRE_RIPPLE`.

An incomplete AV link is `COMPOUND_EXTERNAL_LINK` and does not half-write. A locked participating track is `FIELD_LOCKED`. A missing `fromVersion`/`toVersion` pin is `SOURCE_VERSION_MISSING`. Cycles and depth greater than 8 stay fail-closed. Optical-flow is not a length policy (`UPGRADE_POLICY_UNSUPPORTED`).

Local writing admission now accepts well-formed `retainedSources` entries of kind `sequence` plus referenced `snapshot` blobs, so a historical nest pin can remain valid after the live child advances. This is not a Project `user_version` change, not workspace schema w5, and not OpenNested persist of in-child edits.

## Consequences

I-007 remains partial. Official new suite: 5 tests. Frozen MakeCompound (5) and retime/nest (8) suites were re-run, not rewritten. Analyzer exit 0. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i007-upgrade-nest/`.

## Follow-up

OpenNested, P2 reverse/freeze/smooth, optical-flow, and V-003 stay open. I-006 TrimPlanner surfaces and video muted/solo on SetTrackState stay open and are not closed here.
