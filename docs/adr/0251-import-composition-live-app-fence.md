# ADR 0251 — live-App source fence before preview-consent composition

Status: accepted, Increment 3.52 prerequisite slice only.
Base: `013a8e50c8dcf6be716c065f4e357c636fdc5737`, clean feature branch matching
origin before editing. Normative: [ADR 0248](0248-signed-import-app-composition-plan.md),
[ADR 0250](0250-bounded-signed-import-source-adapters.md) and
[A2/A3/A6](../studio/spec/s8f-signed-import-app-v1.md).

## Concrete planning gap (completed before implementation, t155u)

A2:63–75 requires live App re-sampling after every source-read await and retirement
on App/policy/scope drift. At this base, source_capture.dart:46–64/92–102 checks
only its own local generation; platform adapter entrypoints accept only capture.
Neither can observe a live ImportAppSnapshot while length/read/close is pending.
A check only after choose's Future returns would permit stale reads to EOF.
3.51 qualified bounded sources, NOT this full-composition requirement.

The appended A3 3.52 binding defines the synchronous live predicate, latch,
pre-picker/per-await/post-close checkpoints, safe scopeChanged outcome, App-owner
monotonic generation (including ABA), cleanup and eventual-quiescence rules.
No frozen contract conflict, guessed widget API or new crypto protocol is needed.

## Implemented and independently qualified boundary

An optional internal `currentAppStillValid` callback is forwarded by both existing
App-owned adapters into SkillSourceCapture. Source-only callers retain their old
API behavior; FULL App composition MUST pass a genuine live snapshot/generation
comparison. Omission is NOT valid composition acceptance. False or exception
latches the operation stale, with no subsequent reads or bytes published. Native
close still runs. Cancellation retains its immediate null outcome and capacity
is not released until the pending operation drains. Picker activation stays in
the original synchronous trusted action stack. No error details are exposed.

Seventeen new controlled-reader tests cover pre-picker rejection, callback exception,
synchronous activation, late selection, drift/exception at length/read/EOF/close,
latching, ABA generation, cancel/busy/quiescence and cleanup failure. These test
ONLY the new capture seam. They do NOT implement or qualify the actual App owner,
AppProfile/scope/clock comparator, browser UI, GTK chooser, verifier or importer.
The previous source-adapter/browser/crypto/host/format runtime suites are not rerun.

## Why stop before full composition

The new per-await App fence must be connected to a real App-lifetime owner before
any A4/A5 controls can claim composition. Both App shells still lack that owner,
preview presentation and acknowledgment controls. Their combined A6 actual-host
CSP/readiness, widget, accessibility, no-write/storage/authority and stale-state
acceptance is substantial independent work, not covered by these seventeen tests.
Land the bounded planned seam with its independent evidence, not a partially wired
UI or a claim of combined acceptance. Next 3.53 must finish that existing-App
composition and combined acceptance, including the REAL live comparator and
readiness/default-empty-root behavior. The counter model in this test is not a
production grant/clock service. No new production services or roots are introduced.

No durable installation, cross-namespace import, production roots/FTS/RAG,
real-device/model/provider/paid API/store claims or standing-exclusion surfaces.
DSSE, Ed25519, immutable reports/acknowledgment and invalid-signature refusal are
unchanged. signed=true grants no verification, acknowledgment or execution.
I-037 stays partial; all original remainingAcceptance/remainingScope and the
historical acceptance failure remain unchanged. Counts 0/62/12/13,
fullTasksCompleted=0; T-4/program unfinished; user_version=9;
InversePatch=restoreSnapshot.
