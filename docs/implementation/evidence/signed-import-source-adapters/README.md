# Increment 3.51 — bounded source adapters, not App preview-consent composition

Recorded 2026-11-28 Asia/Shanghai. Base `1c74633c7c03207ee99bae15fef44ed2d9ede86c`
was clean on `feat/studio-foundation-20261125` and identical to its origin upstream
before editing. [ADR 0250](../../../adr/0250-bounded-signed-import-source-adapters.md)
and the appended [A3 ownership binding](../../../studio/spec/s8f-signed-import-app-v1.md)
complete the concrete lifetime/open-deadline gap before implementation (t155u).

## Exact scope / new results

- **24/24 pure-Dart cases**, `unit-tests.log`: zero/1/chunk boundaries/cap-1/cap,
  cap+1/lying length/growth/partial reads, read/length/close faults, copied immutable
  data, one pending picker, cancel/dispose, late unopened reader, exact 29999/30000ms
  deadlines through length/open-port/read/close, and cancellation at each await.
  These are controlled test readers, NOT OS I/O interruption/cryptographic evidence.
- **1 Linux integration test, 5 actual GTK selections**, `linux-tests.log` and
  `linux-results.json`: seven-byte public fixture twice (same-file reselection),
  real OS cancel, exact 4MiB capture, 4MiB+1 rejection. Uses the actual pinned plugin,
  compiled Flutter test App and native reader, not a fake picker. GTK 3.24.49,
  GTK_USE_PORTAL=0, isolated box-only Xvfb. This does not qualify desktop portals,
  hostile filesystem races, manual user interactions or any registered user device.
- **13 Web browser cases**, `web-tests.log` / `web-results.json`: the ACTUAL App-owned
  Web adapter and shared capture helper compiled to Dart-JS, Chrome 156.0.8078.47,
  fresh profile and isolated Xvfb. Trusted CDP Choose/File injection uses public
  fixtures 0/1/65535/65536/65537/4194303/4194304/4194305. Checks <=64KiB Blob slices,
  EOF, complete byte sums, immutable results, pre-allocation overcap rejection,
  reselect/reset, ignored untrusted DOM events, App cancel/busy/late-result drain,
  and terminal unresolved chooser retirement. A separate actual Chrome GTK chooser
  Escape emits a trusted cancel event and resets. CDP empty-file injection itself
  emits NO cancel in this profile: the test asserts pending state and drains it,
  never fabricates isTrusted. Public File injection is a browser-boundary test,
  not manual OS-dialog qualification.
- **48/48 Python checks** (`static-tests.log`): 8 new adapter evidence/preservation
  checks plus 40 existing plan/evidence static checks. These do not execute or
  re-qualify the old importer, verifier, host or format-repair runtimes.
- Analyze: **no issues** for all six new Dart production/test files.
  Format: **6 files, 0 changes**. Actual default Linux App debug and Web App JS
  targets compile (`app-linux-build.log`, `app-web-build.log`); build success is
  NOT runtime/UI/CSP qualification. The SDK's default Web build also reports a
  Wasm dry-run compile, NOT Wasm execution/acceptance. SDK identity is recorded in
  `flutter-version.json` (Flutter 3.50.1 / Dart 3.14.0).
- The unchanged acceptance suite still reports **5 pass / 1 known failure** in
  `test_all_87_overlay_rows_retain_original_acceptance_and_dependencies` at line 52,
  from historical acceptance annotations (`unchanged-acceptance-suite.log`). No
  acceptance test, original remainingAcceptance or remainingScope was rewritten.

Logs normalize trailing terminal padding only.

Final passing evidence above supersedes development harness failures: an initial
Dart Future<void> error-handler typing mistake, GTK automation path-validation
and fake-async scheduling mistakes, and a mistaken expectation that CDP empty
injection would emit native cancel were corrected in NEW tests. No production
security rule or event trust check was weakened to obtain a pass.

## Reproduction (box checkout only)

`/workspace/toolchains/flutter/bin/` supplies Dart/Flutter; commands run at repo root
unless otherwise stated. GTK runner needs Xvfb/xdotool/pkg-config/GTK3; Web runner
needs Chrome/Node/Xvfb/xdotool. Runners create fresh test displays and public fixture
folders, with one fresh browser profile. No real account/browser/user desktop.

```
flutter pub get
dart test packages/studio_assets/test/skills/source_capture/source_capture_test.dart
python3 tools/acceptance/run_skill_source_linux.py
python3 tools/acceptance/run_skill_source_web.py
python3 -m unittest tools.tests.test_signed_import_source_adapters tools.tests.test_signed_import_app_plan tools.tests.test_signed_import_app_host tools.tests.test_signed_import_plan tools.tests.test_signed_import_runtime_contract tools.tests.test_signed_import_web_plan tools.tests.test_signed_import_web_runtime
python3 -m unittest tools.tests.test_acceptance  # known unchanged failure
```

Analyze/format targets are the six `.dart` paths in `source-sha256.json`.
Build commands: `flutter build linux --debug` in apps/studio_demo, and
`flutter build web --no-web-resources-cdn` in apps/studio_web. Runner result JSON
also appears under `/workspace/skill-source-351` (box-only generated output).

## Integrity / limitations / next

`contract.json` binds the exact allowed source/lock delta and unchanged backend,
App-main, host and acceptance bytes. `source-sha256.json` binds tested new sources.
Existing lock records are byte-identical; four added records match the previously
planned archive version/hash pins. http is an unused interface dependency, not
network permission. Common code is opt-in internal and absent from the shared
studio_assets export; no product Choose/preview controls were wired.

The Web adapter harness is a standalone restrictive loopback host, NOT the actual
Flutter App-host CSP qualification and not the combined A6.2 App flow. Its observed
page requests are only index.html and probe.js; no selected-source URL is fetched,
no CSP violations or browser exceptions occur, and local/session storage stays
empty. Do not extend this into full-App no-write/storage or execution acceptance.
No crypto/importer is imported by these tests. 3.46/3.48/3.50 results are neither
repeated nor counted here. No UI integration, production roots or install path.

Next **3.52**: only the completed A1–A6 existing-App selection / immutable preview /
separate non-authorizing acknowledgment composition, with its independent combined
actual-App CSP/readiness/picker/widget/accessibility/no-write tests. Source selection
is not acknowledgment, verification, approval or execution authority; signed=true
is not evidence, and invalid signed input must not downgrade. Default roots stay
empty. No durable installation, cross-namespace import, production roots/FTS/RAG,
real-device/model/provider/paid API/store claims or standing-exclusion runtimes.

Counts stay **0 complete / 62 partial / 12 planned / 13 blocked**; I-037 partial,
fullTasksCompleted=0, T-4/program unfinished, user_version=9,
InversePatch=restoreSnapshot. This increment stops after adapter qualification.
