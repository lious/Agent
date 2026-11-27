# ADR 0156 — Official I-040 async generation candidates and editable NLE insert

## Status

Accepted for Increment 2.57 as the first I-040 slice. I-040 moves planned → partial and is not marked complete. V-019 stays blocked; this increment does not claim a video-mode qualification, does not enable production, and does not call a paid API. I-033 reconciler leftovers and I-041 leftovers are not re-qualified. I-046, I-051, I-054, I-029, I-010, and I-009 leftovers are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, and I-041 stay partial and are not marked complete. V-009, V-016, V-017, V-018, and V-021 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. This increment does not invent a WorkflowCoordinator, does not auto-connect an account, and does not start quote/apply.

## Decision

s8i defines `AsyncTaskAdapter`: submit once, persist `task_id`, and poll with GET. An unknown status must not re-POST. Timeout is pending reconcile, not a failed refund. A late fee enters the ledger once; late media enters a sandbox candidate and is not auto-applied. Cancel is only reliable while PENDING; RUNNING may be unsupported; a local cancel epoch immediately forbids auto-apply. Read retries may back off; a submit retry must first check the existing task and must not double-bill.

s8i continuation keeps the original timeline clip and its original audio, inserts only the verified suffix, and does not duplicate the context prefix. Full returned duration is what is billed, not only the added seconds. An uncertain boundary is `unknown` QA and must never auto-splice. A tail-frame bridge is `approxContinuation`, needs re-approval, and is not a silent fallback. Missing first-last or true extend capability is refused. An unverified restyle profile is `UNVERIFIED_VIDEO_RESTYLE_PROFILE`. Invented `audio=false` on Wan 2.7 is refused.

s8k says one-shot or multi-shot insert is an editable NLE clip (trim-able, not only a flattened MP4). Locked original in-out, audio, and hand-edited captions are preserved and must not be overwritten by regeneration.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_generation/lib/video_generation_provider.dart`:

- `VideoGenerationProvider.submit` posts and bills at most once per idempotency key. `poll(..., rePost: true)` is `UNKNOWN_NO_BLIND_RETRY`. `acceptLate` quarantines the candidate without a second bill or auto-apply. `cancel` of a running task is `FEATURE_NOT_IMPLEMENTED`. A late or cancelled candidate is not hung on the timeline. No paid API is called. `productionEnabled`, `v019Claimed`, and `accountAutoConnected` stay false.
- `insertShots` and `insertContinuation` return editable clips (`canTrim`, not `flatMp4Only`). Continuation preserves the original clip and audio and inserts only the suffix. Auto-splice of an uncertain boundary, or inventing `audio=false` on Wan 2.7, is `UNSUPPORTED_EDIT_TECHNIQUE`. Unsupported first-last or extend is `CAPABILITY_UNSUPPORTED`. Restyle is `UNVERIFIED_VIDEO_RESTYLE_PROFILE`. Unapproved approx continuation is `APPROVAL_REQUIRED`. Native extend bills the full returned duration.
- Overwriting locked audio is `TRACK_LOCKED`. Overwriting a hand-edited caption is `FIELD_LOCKED`. Compile does not write a document.

The Increment 2.56 I-041 official suite was re-run, not rewritten. A real Wan/DashScope path, V-019 qualification, and WorkflowCoordinator quote/apply remain unopened.

## Consequences

The first I-040 leftover acceptance items (duplicate/late/cancel/unknown do not double-bill, one-shot or multi-shot insert stays an editable clip rather than only a flat MP4, and locked original audio or hand-edited captions are not overwritten) are officialized at this compiler bound. V-019 stays blocked, so I-040 stays partial and is not marked complete. 87-task counts become 0 complete / 48 partial / 26 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i040-generation-provider/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a WorkflowCoordinator or call a paid API. Do not claim V-019. Do not re-qualify I-040, I-033, I-041, I-009, I-046, I-051, I-054, I-029, or I-010 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not start I-035 as a product loop or claim a V-020 precision/recall achievement. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, or I-040 complete.
