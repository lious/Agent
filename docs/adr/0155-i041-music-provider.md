# ADR 0155 — Official I-041 MusicProvider refusals, BeatGrid snap, and duck proposals

## Status

Accepted for Increment 2.56 as the first I-041 slice. I-041 moves planned → partial and is not marked complete. V-016, V-017, and V-018 stay blocked; this increment does not claim ACE, Stable Audio, or YuE2 qualification and does not run real inference. I-009 bus/gain leftovers and I-033 reconciler leftovers are not re-qualified. I-046, I-051, I-054, I-029, and I-010 leftovers are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, and I-046 stay partial and are not marked complete. V-009 and V-021 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. This increment does not invent a limiter or bus Effect, does not call a paid API, and does not treat ABC as an executable script.

## Decision

s8d places ACE-Step 1.5, YuE2, and Stable Audio Open Small on one `MusicProvider` port, with each profile independently enabled. ACE can be planned without waiting for YuE2. Turbo does not inherit Base-only `extract` / `lego` / `complete`. YuE2 Vocal/Ins parts are a symbolic score, not verified native audio stems (`STEM_CAPABILITY_UNAVAILABLE`). `Character.voice` cannot automatically become a YuE2 voice clone. Song-score ABC is not an executable script and must not load a URL, include, or plugin. ACE BPM must be an integer (`BPM_INTEGER_REQUIRED`). Meter is only `2/4`, `3/4`, `4/4`, or `6/8`; any other meter is `CAPABILITY_UNSATISFIED` and is not silently dropped. An uninstalled transcriber is `TRANSCRIBER_UNAVAILABLE`. A missing model is `MODEL_UNAVAILABLE`. A commercial license gap is a warning, not a grant.

A `BeatGrid` holds declared integer sample events. Algorithm suggestions are not measured beats. Snapping a cut to that synthetic ground truth must stay within 1 sample of the declared event. An uncertain grid is not a confident measured beat.

`DuckingPlanner` emits a proposal only. Manual gain points are not rewritten. A locked track or locked volume is `TRACK_LOCKED` / `MANUAL_LOCKED`; a new Effect must not bypass the lock. Existing VO or captions are not overwritten. This is not a limiter. A late cancel isolates the candidate, accounts the fee against the existing receipt, does not attach to the timeline, and does not promise a refund. Unapproved paid generation does not start.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_generation/lib/music/music_provider.dart`:

- `MusicProviderCompiler.plan` allows an installed ACE profile even when YuE2 is not installed. Turbo Base-only tasks and unsupported meters are `CAPABILITY_UNSATISFIED`. YuE native stems are `STEM_CAPABILITY_UNAVAILABLE`. Voice clone and ABC URL/script loading are `TOOL_NOT_ALLOWED`. Fractional ACE BPM is `BPM_INTEGER_REQUIRED`. An uninstalled profile is `MODEL_UNAVAILABLE`. License warning is not a grant. Compile does not submit or call a paid API, and does not claim V-016/V-017/V-018.
- `snapToGrid` snaps to the nearest declared integer-sample event; error against that synthetic ground truth is ≤ 1 sample. An uncertain grid is `CAPABILITY_UNSATISFIED`.
- `proposeDuck` preserves manual gain points, does not auto-apply, and does not invent a limiter. Locked track or gain is `TRACK_LOCKED` / `MANUAL_LOCKED`.
- `lateCancel` accounts the settled fee, quarantines the candidate, and does not hang it on the timeline or promise a refund. `submitPaid` without approval is `APPROVAL_REQUIRED`.

A real ACE/YuE runtime, V-016 qualification, and a limiter remain unopened.

## Consequences

The first I-041 leftover acceptance items (ACE can proceed without waiting for YuE2, beat snap stays within 1 sample of a declared synthetic grid, hand-adjusted gain and locked tracks are not overwritten by a duck proposal, and a late cancel still accounts the fee) are officialized at this compiler bound. V-016/V-017/V-018 stay blocked, so I-041 stays partial and is not marked complete. 87-task counts become 0 complete / 47 partial / 27 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i041-music-provider/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a real ACE/YuE engine or claim V-016/V-017/V-018. Do not invent a limiter. Do not re-qualify I-041, I-009, I-033, I-046, I-051, I-054, I-029, or I-010 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not start I-035 as a product loop or claim a V-020 precision/recall achievement. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, or I-041 complete.
