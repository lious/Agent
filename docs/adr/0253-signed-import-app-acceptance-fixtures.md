# ADR 0253 — actual-App signed-import acceptance fixtures

Status: accepted planning supplement, Increment 3.54; implementation deferred.

The clean feature branch matched origin at
`5220d66b0c00008f215efb9bbcdca0ec57d0f5f3` before editing.

## Context and concrete gap

ADR 0252 explicitly leaves browser positive trusted-test-profile acknowledgment
and keyboard/navigation/pagehide/late-state combinations unfinished. The existing
WebStudioApp's policy and clock are private hardcoded defaults (main.dart:28–36,
149–168). A6 permits public fixtures but does not bind how a separately compiled
fixture gains trusted composition input without a production enrollment surface.
Replacing the actual App, patching compiled JS, reading URL/browser state or
promoting wall time to trusted confidence would not satisfy the contracts.

## Decision

Adopt the normative [fixture/matrix supplement](../studio/spec/s8f-signed-import-app-acceptance-v1.md):
P2 separates a test-only entrypoint and named actual-App test constructor from
unchanged default construction; P3 binds private pre-publication retirement, not
a consent/action endpoint; P4 requires exact artifact/host/fixture provenance and
continuous no-write observations; P5 enumerates remaining combined case IDs.
Use the real Web factory/importer and real separate acknowledgment button. Keep
fixtures/public signing material outside production imports and verify default
artifact exclusion. Source-phase fakes are labeled tests only, not File or crypto
qualification. No existing signature, snapshot, source or privilege contract changes.

## Scope and landing

Land planning and static preservation checks only. Implementing the new trusted
fixture seam AND proving its artifact exclusion/lifetime discipline AND completing
the browser/native matrix is not treated as a single already-qualified change.
Recommended 3.55 implements the minimal seam and B01–B04 first with fresh combined
evidence; the other enumerated rows remain explicit. No current runtime is changed,
no old runtime suites rerun, no A6 or I-037 completion claim.

Counts remain 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0, I-037 partial, T-4/program unfinished. Preserve original
remainingAcceptance/remainingScope, historical 5-pass/1-failure acceptance suite,
user_version=9 and restoreSnapshot. All standing exclusions remain.
