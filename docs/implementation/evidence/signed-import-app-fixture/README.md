# Increment 3.55 — minimal actual-App fixture seam and B01–B04

Base clean/matching origin: 5e6f241ac51f861359fbd6ab2405163cc817d443.
See ADR 0254 and the normative App acceptance fixture plan/3.55 clarification.

## Evidence and reproduction

- `python3 tools/acceptance/run_skill_import_app_fixture.py`: THREE new build
  artifacts and FOUR new fresh-browser B01–B04 cases. No historical suite is run.
  Artifacts: default OFF, ordinary opt-in, fixture test entrypoint. Public root/
  fingerprint/rebuild-control strings and test entrypoint map appear ONLY in the
  fixture artifact. The source graph/normal null constructor and input digests
  bind the fixed confident test clock to that entrypoint, not production time.
- `artifacts.json`: main/source-map/input digests and exclusion assertions.
- `B01.json` through `B04.json`: actual executable asset hashes, strict CSP/SRI,
  observed requests, exact public fixture provenance/report expectations, no
  exception/violation, and unchanged storage plus continuous mutation observations.
  B01: real Tab/Enter Choose and separate Enter acknowledgment.
  B02: real Tab/Enter Choose and separate Space acknowledgment.
  B03: real keyboard Choose, actual standard browser semantics DOM action twice,
  disabled target excluded from keyboard focus, repeated pointer does not revive it.
  This is NOT an OS assistive-device/screen-reader qualification.
  B04: real App rebuild and model-shaped postMessage cannot acknowledge/change
  the retained report. All cases use actual File/real web verifier/repository.
- `flutter test test/import_fixture_lifetime_test.dart` in apps/studio_web:
  FOUR new App-private lifetime seam unit cases; no old owner/fence tests rerun.
- `analyzer.log`: no issues over changed App code/tests and fixture generator.
- `format.log`: six changed/new Dart files, zero formatting changes.
- `static-tests.log`: new executable source/evidence/status preservation checks.
- `unchanged-acceptance-suite.log`: 5 pass / 1 historical strict-equality failure;
  test and original acceptance wording untouched.
- `flutter-version.json`: actual SDK; `runner.log`: final full command output.

The deterministic signing seed is PUBLIC bytes 1..32, generated before the
post-open observation baseline, never user credentials or production publisher
material. Empty tool grants remain empty even when verified acknowledgment
succeeds; summary documentWrites=0/executionAuthority=false, report cleared.
The component creates no approval receipt, installation, persistence or execution.
No source URL fetch, publisher lookup, upload, analytics or new import request.
Default App startup writes are the baseline, not attributed to this component.

## Honest remaining boundary

Full A6 remains false: B05–B11/L01–L03/N01–N02 require fresh combined evidence.
Fixed fixture time does not qualify forward-time/expiry or production clocks.
Recommend 3.56 B05–B08 (cancel/reselect/navigation/pagehide/lifecycle), then remaining
explicit rows. No old runtime/vector/host/adapter/owner/plan qualification reruns.
Counts unchanged 0 complete / 62 partial / 12 planned / 13 blocked; I-037 partial,
fullTasksCompleted=0, T-4/program unfinished. Original remainingAcceptance and
remainingScope, user_version=9, restoreSnapshot unchanged. LICENSE.core and all
third-party/crypto/host/lock files unchanged. No paid API, deploy, Mac/XS, device/
model/provider acceptance, production roots/FTS/RAG, install or cross-namespace flow.

Development failures are not acceptance: initial helper import linting was fixed
without suppressions; browser keyboard tests now wait for real focus propagation,
and repetition targets the disabled acknowledgment rather than another control
that receives focus after success. Final full build/browser run passed; the final
runner has no reuse/skip/debug success path and always verifies vendor integrity.
