# Increment 3.48 — independent Web import-to-preview evidence

Base: `462b0a25a02c14be6fb9019c6ddeec0a50525629`; clean feature tip matched origin
before editing. Decision: ADR 0247. Existing s8f signed/Web plans and ADRs 0244–0246
are sufficient and unchanged. No new cryptographic/privilege protocol.

## Runtime evidence

`browser-results.json` is the unedited successful real-browser runner result.
- Dart SDK 3.14.0, `dart compile js -O2`, main browser realm.
- Google Chrome 156.0.8078.47, isolated Linux x86_64 **test host**, not a device claim.
- Exact wrapper 0.8.4 / core 1.0.22 startup assertion; artifact SHA256/SRI and
  compiled importer / App bootstrap digests recorded in that result.
- 21 fresh browser realms, **68 grouped Dart-harness assertion cases**, including
  **40 compiled importer cases**. This is the checked-in custom Dart browser
  harness, not a claim of 68 package:test framework cases.
- 210 UNIQUE Wycheproof vectors passed first through the production typed Web
  bridge, with RFC8032 1–3 and explicit S/point/length/tamper negatives. The
  additional mutating-upstream realm repeats the same 210, NOT 420 unique vectors.
- Next the actual compiled importer tests pass against offline public signed DSSE
  fixtures; crypto-only JavaScript/API presence or native results do not stand in.
- SRI tampering cannot execute; actual restrictive CSP refusal fails terminally.
  No CSP/security/certificate disable flag is used. `--no-sandbox` is the isolated
  container Chrome process setting, not relaxed web-origin/CSP enforcement.
- Before-ready, symbols/version/type, foreign/replaced bridge, CSPRNG, deadline,
  late callback, shared/resizable/string rejection, aliasing, exception and
  teardown cases pass. No skip/fake verifier or alternate artifact fallback.
- First-load async policy/clock/grant drift is not captured stale. Report/consent
  are immutable, one-use and realm-local; zero writes or execution/tool authority.
  Browser storage calls and unexpected test-origin requests are asserted absent;
  CSP disallows off-origin App connections and executable sources.

The observed profile is the pinned COMBINED JS/WebAssembly artifact under this
CSP. Its internal JS-vs-Wasm execution path was not instrumented or asserted.
These results do not qualify other engines, workers or Dart-to-Wasm.

## Reproduction and static checks

From repository root:

```
python3 packages/studio_assets/test/skills/signed_import_web/make_fixtures.py --check
python3 tools/acceptance/run_signed_import_web.py
python3 -m unittest tools.tests.test_signed_import_web_runtime tools.tests.test_signed_import_web_plan tools.tests.test_signed_import_runtime_contract tools.tests.test_signed_import_plan
python3 -m py_compile tools/acceptance/run_signed_import_web.py tools/tests/test_signed_import_web_runtime.py packages/studio_assets/test/skills/signed_import_web/make_fixtures.py
/workspace/toolchains/flutter/bin/dart analyze packages/studio_assets
```

All pass: 25 official Python runtime-evidence/plan/preservation checks, whole-assets
analysis, browser-JS compile and changed-Dart format / diff checks. Outputs kept
outside the repo at `/workspace/signed-import-web-348`; reproduction requires the
recorded browser/Dart toolchains and Python cryptography for offline PUBLIC test
fixtures. The vendored runtime's exact hashes are checked before ANY execution.
The fixed CSP is served as an actual HTTP header; every App/test script also has
pre-execution SRI. Test-only fault injection never becomes a product verifier API.

Original native crypto/parser/schema/privilege sources are unchanged. Native
entry/test imports only route through the conditional seam (assertions unchanged);
NO old native/import/format/device/model/provider runtime is rerun or requalified.
The pre-existing strict-equality test_acceptance failure and wording remain
untouched, not repaired or rerun here; baseline in
`../signed-import-plan-v1/baseline-acceptance-failure.json` remains authoritative.

## Honest boundary

I-037 stays partial, fullTasksCompleted=0; **0 complete / 62 partial / 12 planned /
13 blocked**; T-4/program unfinished. Original remainingAcceptance and remainingScope
are preserved (only explicit Web-profile scope/evidence appended). Project
user_version=9 and InversePatch=restoreSnapshot remain unchanged.

Not opened: product UI/file-picker wiring, production publisher roots, durable
installation, namespace transfer, production FTS/RAG, deferred art-page/runtime or
hardware work, user Mac/XS, paid APIs, real devices/models/providers, deployment,
main merge or store release. Signature verification and `signed=true` grant no
execution/approval. The next recommendation is only the already-listed App
selection/preview-consent composition planning prerequisite, not invented widget
APIs or permission to install/run a pack.
