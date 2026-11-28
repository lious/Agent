# Increment 3.53 — existing-App signed import composition

Base: `2a36cc38f2ba54c4f04b1a1ea5a754dc7d325575`, confirmed clean and identical to
origin/feat/studio-foundation-20261125 before editing. Decision:
[ADR 0252](../../../adr/0252-existing-app-signed-import-composition.md), normative
[App plan](../../../studio/spec/s8f-signed-import-app-v1.md) and ADRs 0248/0250/0251.

## Implemented and independently exercised scope

Opt-in, default-OFF composition inside the two existing Apps, not a new product
App or shared editor API: actual owner/comparator, readiness gate, synchronous
Choose, bounded capture and immutable literal preview, separate one-use standard
accessibility acknowledgment, cancellation/discard and terminal retirement.
No acknowledgment grants execution authority. `signed=true` proves nothing.
Invalid-signature failures are not retried as unsigned input. Existing verifier,
store, editor, SDK and Web host integrity/CSP bindings are unchanged dependencies.

The 3.53 plan supplement precedes the corresponding implementation: selected/read
phase observation; native FoundationApp first-frame project ownership; real
workspace/project identity in addition to equal-looking scope snapshots.

- `widgets.log`: **18 passed** new real owner/repository and widget cases, including
  trusted isolated public-root/time acknowledgment, typed drift, ABA, late source,
  backend failure, invalid-signature refusal, literal bounded rendering, trust
  labels, accessibility action, cancellation and owner replacement.
- `linux-tests.log`, `linux.json`: **1 passed** new actual unchanged FoundationApp /
  StudioWorkspace plus real GTK chooser and actual importer. Default empty roots /
  unknown clock yield needsReview, acknowledgment disabled, then dismissal.
  Project canonical bytes, directory lists and all test-directory file bytes are
  unchanged after preview/dismiss; transient SQLite `*-shm` is explicitly excluded
  from path/file-byte comparison. Baseline follows normal App initialization, not an
  assertion that App startup itself writes nothing. Approved SQLite 3.54.1 is an
  existing dependency, not re-qualified; its runtime guard is never disabled.
- `web-tests.log`, `web-*.json`: **4 passed** fresh actual compiled WebStudioApp
  profiles: normal, missing backend, CSP-blocked backend, SRI-tampered backend.
  Actual accessible Choose is disabled in all backend failures; zero chooser
  invocations, no unverified vendor marker execution. Normal uses trusted browser
  input/File injection, actual needsReview preview identities and dismissal;
  no new import requests/CSP violations, no observed import IndexedDB mutations,
  unchanged IDB key/record plus local/session snapshots. Artifacts are verified
  before serving/execution. This is the existing App combined with the unchanged
  strict CSP/SRI/style-nonce/self-hosted renderer, not the historical CSP harness.
- `analyzer.log`: no issues. `format.log`: twelve files, zero changes.
- `static-tests.log`: six new composition checks plus 54 existing plan/evidence
  preservation checks, **60 passed**. No historical runtime suites rerun.
- `unchanged-acceptance-suite.log`: unchanged **5 passed / 1 historical failure**
  from strict equality against historical acceptance annotations. Neither the
  test nor original acceptance wording was edited.
- `contract.json`: final source digests, exact allowed runtime delta, preservation
  digests, unchanged status counts and explicit incomplete full-A6 flag.

## Honest remaining acceptance

This is DEV/default-profile composition evidence, NOT complete A6/release
acceptance. Actual-browser positive trusted-test-profile acknowledgment and the
remaining complete keyboard/navigation/pagehide/late-state combined matrix remain
for **3.54**. Positive roots/time in widget tests are PUBLIC isolated fixtures;
both deployed App policies still have EMPTY roots/grants and unknown clock.
No production root/clock provisioning, durable install, cross-namespace import,
production FTS/RAG, real device/model/provider/paid API/store-release qualification.
No rerun or expanded claims for 3.31–3.52. I-037 remains partial, counts remain
**0 complete / 62 partial / 12 planned / 13 blocked**; fullTasksCompleted=0,
T-4/program unfinished, user_version=9, InversePatch=restoreSnapshot.

## Verification environment disruption

Late verification observed an unexpected unrelated deletion of tracked
`packages/studio_assets/third_party/sodium_web/LICENSE.core` and missing compiler /
development dependencies. Cause is unknown; the deletion was NOT made by this
increment, was not restored over another actor's change, and is excluded from the
commit. A detached verification worktree of the same repository preserves that
tracked file from Git and verifies only this increment's staged patch. The
original checkout therefore retains that unrelated deletion.

The box's documented Flutter compiler/GTK prerequisites and existing plugin/store
development headers were restored via the package manager. Disposable Flutter
build caches were regenerated after a stale CMake system-install target; no App
was installed to /usr/local. The new runner explicitly selects the existing
approved SQLite directory, matching the repository's established acceptance
runner convention; unapproved system SQLite was refused, not allowed around.
Final native and widget checks passed afterward. Development failures (missing
headers, stale cache, wrong system SQLite) are not acceptance. The original
verifier, store guard, CSP and cryptographic bounds were not relaxed. See
`environment.json` and `flutter-version.json`; no user computer was involved.
