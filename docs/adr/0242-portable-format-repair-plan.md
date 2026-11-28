# ADR 0242 — Complete the portable format-repair plan before implementation

## Status and authorization
Accepted as the plan-only Increment 3.43 under t155u: implementation-discovered
planning gaps are supplemented before implementation proceeds. Base: 6951d6b.

## Decision
The normative supplement is [10E format repair v1](../studio/spec/s10e-format-repair-v1.md), linked from s10b, s10c, s10d, s10e and s12a.

It fixes all five previously identified bindings: single public command claim
with internal attempt IDs; per-phase journal IDs with retained failed outcome;
cumulative estimated input plus text/tool-JSON charges; structured completion
classification separate from frozen assembler errors; and a smaller output
request with exact prompt hash and a fresh pending-approval identity.

The format-only retry is pre-dispatch pure model regeneration, NOT resurrection
of a terminal Step or a paid submission retry. Valid repaired output is a
pending preview and cannot use the original command approval. No new execution
privilege or general workflow coordinator is introduced.

## Why implementation is the next increment
These bindings jointly change the portable request/completion metadata, budget
meter, journal use and pending-approval handoff. Landing the reviewed contract
first provides one coherent prerequisite; runtime implementation and adversarial
interface tests are reserved for Increment 3.44. No executable repair is claimed
here. Existing runtime files and frozen stream tests remain unchanged.

## Checks and evidence
`evidence/format-repair-plan-v1` contains a documentation-contract manifest,
consistency-test log and post-edit source hashes. Planned acceptance case names
are a checklist, NOT executed product tests. The Python tests only check plan
links, five bindings, fixed suffix, append-only specification changes and frozen
artifact hashes. They do not exercise inference, repair, devices or providers.

No task-status field, original remainingAcceptance/remainingScope, original Page,
capability table, schema, Project user_version (9), or InversePatch kind
(restoreSnapshot) changes. Counts stay 0 complete / 62 partial / 12 planned /
13 blocked; fullTasksCompleted=0; T-4 and program remain unfinished.
Signed-pack verification policy and all unrelated candidates remain unopened.
