# ADR 0254 — actual-App public-fixture browser acknowledgment

Status: implemented for B01–B04 only, Increment 3.55.
Clean base and identical tracked origin feature tip confirmed before editing:
`5e6f241ac51f861359fbd6ab2405163cc817d443`.
Normative: App acceptance fixture plan v1, ADR 0253 and ADRs 0248/0250/0251/0252.

## Precise observation binding completed before its test

The appended 3.55 plan section binds B03 to the actual standard browser semantics
DOM button action, NOT an OS assistive-device/screen-reader claim. B01/B02 still
require independent trusted keyboard activation. B04 uses a fixture-only standard
App-root rebuild control/count, absent from default artifacts. No private Dart
consent function, JS export or message endpoint is added.

## Minimal implementation

WebStudioApp.testImport accepts an App-private immutable typed configuration.
Production construction sets it to null. The actual project first opens, then
the fixture policy factory receives the real AppProfile/namespace exactly once;
its policy is cached across rebuilds. The fixture lives in a separate test Dart
entrypoint: public deterministic key from seed bytes 1..32, threshold/epoch 1,
fixed time 1000, confidence true, no rollback, EMPTY grants. No disabled policy or
unknown clock is substituted in that fixture. Normal App defaults stay disabled
policy/empty roots/unknown clock; wall time is never promoted to confidence.
The real createWebSignedSkillRepository, source adapter, owner, immutable panel
and private action port remain the path; no verifier/repository-success stub.

An App-private lifetime signal retires listeners synchronously BEFORE fixture
replacement publication. Its terminal generation immediately retires late/ABA
registrations; panel disposal unregisters. Owner teardown suppresses child repaint
requests while still retiring/cancelling/discarding synchronously. No report,
gesture or authority crosses this signal. The four new pure seam unit cases do
not claim full browser navigation/late-state acceptance; those rows are deferred.
The minimal configuration intentionally supplies a fixed fixture sample for these
four cases; later forward-time/expiry rows still require their planned trusted
clock progression and cannot be claimed from replacing this whole configuration.

## New independent evidence

[evidence](../implementation/evidence/signed-import-app-fixture/README.md):
- Three real release Dart-to-JS/CSP builds: default OFF, ordinary opt-in, separate
  fixture entrypoint. Default artifacts/maps exclude public root/fingerprint,
  fixture rebuild controls and test entrypoint; fixture artifacts include them.
  Source digests and constructor/import checks bind the trusted test time to the
  test entrypoint. No production-root provisioning or deployment.
- Four fresh browser profiles B01–B04 all pass with actual App/CSP/readiness/File/
  repository/immutable report. Keyboard Tab/Enter Choose; separate Enter/Space
  acknowledgment; standard semantics DOM action/repetition; actual App rebuild
  and model-shaped message never auto-acknowledge. Repeated acknowledgment cannot
  restore the report; disabled target is excluded from keyboard focus.
- Exact namespace/epoch/hash/fingerprint/tool/diff/license-warning identities;
  literal pack title. Continuous DB/cursor/local/session mutation observations,
  full storage record snapshots, and zero new requests after post-open baseline.
  Strict CSP/SRI retained; vendor verified BEFORE execution; all served executable
  digests and actual SDK recorded. CDP File injection is not manual OS selection.

Four new lifetime unit tests, new preservation static tests, clean analyzer and
format checks accompany these cases. Historical acceptance remains 5 pass / 1
strict-equality failure unchanged. No old runtime/plan suites were re-qualified.

## Remaining boundary

Full A6 remains FALSE. B05–B11, L01–L03 and N01–N02 are still explicit and
unqualified; no negative signature, teardown, late-state, revocation/expiry or
native combined matrix result is inferred from these four positive cases.
Recommended 3.56 starts B05–B08. I-037 remains partial, counts 0/62/12/13,
fullTasksCompleted=0, T-4/program unfinished; original remainingAcceptance and
remainingScope unchanged. user_version=9, InversePatch=restoreSnapshot.
No installation, cross-namespace import, production roots/FTS/RAG, device/model/
provider/paid API/store-release acceptance, user Mac/XS, main merge or force push.
