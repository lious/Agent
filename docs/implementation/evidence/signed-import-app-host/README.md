# Increment 3.50 — actual App-host CSP gate ONLY

Base `5a02ca7ec6d8d5dbfd8bd1f530c3ca3f9872e922`; clean feature branch matched its
tracked origin before editing. ADR 0249 implements only the A5 App-host prerequisite
from the completed App plan. No additional plan binding or protocol conflict.

## Independent browser evidence

`browser-results.json` is the successful official runner output; `actual-app.png`
is its normal-profile screenshot of the EXISTING App at revision 0, not a skill
selection/preview UI. Actual compiled target: apps/studio_web/lib/main.dart,
Flutter 3.50.1 / Dart 3.14.0 / engine 4d35714800b9266b6693a58e1225ecd7e9e45ed7,
release Dart-to-JS, main-realm CanvasKit, --no-web-resources-cdn, Chrome
156.0.8078.47 on this Linux test host only. All executable/renderer assets observed
being served have recorded SHA256; exact vendor SHA256/SRI is checked BEFORE code
execution. No promise about other engines, devices or production hosting.

Six fresh real-browser profiles passed their independent expectations:
1. Normal: actual App first frame/view, nonce-bearing engine style, existing crypto
   bootstrap startup ready, zero CSP/runtime/network failures or off-origin requests.
2. Tampered vendor SRI: App still renders, crypto startup fails; tamper cannot execute.
3. Intersected CSP excludes vendor: vendor blocked, startup fails; no relaxed retry.
4. Missing vendor: startup fails, no alternate URL/artifact.
5. Wrong style nonce: actual engine styles denied, host profile NOT admitted.
6. Missing style nonce: actual engine styles denied, host profile NOT admitted.

Style-negative cases can still have a ready crypto backend; that is not host/UI
success. The positive predicate requires all host invariants, not first frame alone.
Unique response style nonces come from CSPRNG (16 bytes), never from pack data.
A plain static server without the tested HTTP headers/SRI/nonce profile is NOT
qualified merely because the App files exist. The source bootstrap allows that
normal development case but makes no security-profile claim for it.

The runner compiles the actual App/index/custom bootstrap, injects only trusted
HTTP nonce/SRI/test probes, and serves all App/renderer/font/vendor assets from
loopback. It does not run a substitute App or standalone importer as App evidence.
No security/CSP/certificate check is disabled. --no-sandbox is solely the isolated
container Chrome process setting. Fresh profiles contain no signed-in user data.
No service worker is configured/registered. Existing App IndexedDB project opening
is baseline startup, not a claimed zero-App-write result or pack installation.

## Reproduction and official checks

From repository root:

```
python3 tools/acceptance/run_signed_import_app_host.py
python3 -m unittest tools.tests.test_signed_import_app_host tools.tests.test_signed_import_app_plan tools.tests.test_signed_import_web_runtime tools.tests.test_signed_import_web_plan tools.tests.test_signed_import_runtime_contract tools.tests.test_signed_import_plan
python3 -m py_compile tools/acceptance/run_signed_import_app_host.py tools/tests/test_signed_import_app_host.py
node --check tools/acceptance/signed_import_app_host/browser_probe.cjs
node --check tools/acceptance/signed_import_app_host/host_probe.js
node --check /workspace/signed-import-app-host-350/web-host/flutter_bootstrap.js
```

From apps/studio_web: `/workspace/toolchains/flutter/bin/flutter analyze --no-pub`.
All pass: six actual browser profiles, 40 Python evidence/plan/preservation checks
(6 new host checks), Python/JS syntax, actual App build/analyze and git diff checks.
Flutter's default build-time Wasm dry-run log is NOT Dart-to-Wasm runtime acceptance.
Outputs stay at `/workspace/signed-import-app-host-350`, outside the checkout.
Historical-preservation checks read the 3.50 snapshot instead of banning planned
future App source changes. They are not previous runtime requalification.

## Unfinished scope

SOURCE ADAPTERS ARE NOT QUALIFIED. No native selector was installed or lock
changed; no selected File/GTK read/cancel flow or preview/consent UI was implemented.
Old native/browser importer/crypto/vector/format suites were not rerun; existing
backend startup is only a host dependency smoke check, not fresh backend acceptance.
Original acceptance and remainingScope and the pre-existing strict-equality failure
are unchanged. Project user_version=9 / InversePatch=restoreSnapshot remain.

I-037 stays partial; fullTasksCompleted=0; counts 0 complete / 62 partial /
12 planned / 13 blocked; T-4/program unfinished. No installation, namespace
transfer, production roots/FTS/RAG, user Mac/XS, excluded runtimes/hardware,
real device/model/provider/paid-API/store or production deployment acceptance.

Recommended 3.51: qualify bounded Linux GTK and Web File source adapters as the
OTHER prerequisite, then consider full App selection/preview-consent composition
only after both gates pass. Do not infer UI or source qualification from this host.
