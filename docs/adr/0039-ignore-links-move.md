# ADR 0039 — Ignore links and groups for a single move

## Status

Accepted for Increment 1.32 on the existing I-005 MoveClips command. I-005 remains partial.

## Decision

Open the already-specified `MoveClips.includeLinks` flag (default `true`). When `includeLinks` is `false`, the move applies only to the explicit clip IDs: unselected AV link partners and unselected selection-group members are not expanded. If some but not all members of a `LinkGroup` move, that group is marked `syncPolicy=allowOutOfSync` and stored offsets are left as originally recorded. `LINK_OFFSET_MISMATCH` is issued only when `syncPolicy` is not `allowOutOfSync`. Local admission still requires a two-member video+audio link and now accepts `preserve` or `allowOutOfSync`.

Default `includeLinks=true`, ripple trim/delete link expansion, insert-move leave-gap, and explicit-range ripple close are unchanged. Reject, overwrite and insert all honor the flag and stay distinct. Auto-close as part of a move is still not a legal `MoveClips` mode. The workbench exposes a same-command checkbox and captures Alt at pointer-down for the whole gesture. No new table is added.

## Consequences

A partially moved AV pair can be admitted and reopened with `allowOutOfSync`. Overwrite group repair keeps a complete two-member group even when that policy is set, so a later overwrite does not silently drop the link. Caption cue-follow, marker business, new-track, cross-project bake, the OS clipboard, and I-006 roll/slip/slide remain closed.

## Evidence

`docs/implementation/evidence/ignore-links-move/`.
