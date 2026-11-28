# Increment 3.63 — official N01–N02 native profile qualification

Base `91439223878707181e3dadd01786e9d9a60ca892` was clean on
feat/studio-foundation-20261125 and matched its tracked origin before editing.
This increment completes the Increment 3.63 observation-wiring supplement
(ADR 0262 and the native v1 append), then independently qualifies all seven
official N01–N02 profiles, reusing already-qualified NG0–NG3 transports. It
does not requalify NG0–NG3, B01–B11, L01, L02–L03, G3, or Increments 3.31–3.62.
Combined G1–G5 and full A6 are not claimed. L01 was not rerun.

## Independently verified scope

- Fixture-only host extensions: optional external `ImportCompositionLifetime`,
  `wrapMaterialApp=false` so a test shell can own `MaterialApp`, and
  fixture-mode `FocusScope` plus `ExcludeFocus` on FoundationApp so N01 Tab
  stays on the import panel. Default construction and `main.dart` are unchanged.
  Navigate/rebuild/unmount chrome lives only in the integration test shell.
- Official pack: public FixtureSigner(1), actual workspace namespace
  `studio_demo/local/default`, one admitted `media.analyze` step. A literal
  empty-requiredTools filmCraft pack is impossible under frozen
  `film_schema` steps minItems=1 and toolId ⊆ requiredTools. The verified
  report records `missingTools=["media.analyze"]` under empty App grants.
  Acknowledgment remains preview-only and does not grant tools.
- N01-enter / N01-space: actual GTK Open File helper plus xdotool Tab/Return
  Choose, then a separate Return or Space acknowledgment on the focused
  standard Flutter control (key and label inspected). Repeat input cannot
  reuse the consumed gesture; after ack the disabled control leaves tab
  traversal, so a bare Return is not sent (that would legally start Choose).
- N01-semantics: framework `SemanticsAction.tap` on the enabled acknowledgment
  node (id/label/enabled/hasTap recorded). This is not OS assistive-device
  qualification. Repeat semantics/pointer does not create a second summary.
- N02-preview-navigation / dispose: verified preview, then
  `invalidateBeforePublication` immediately before `Navigator.push` to a
  labeled fixture route, or actual host unmount. Pop/rebuild does not revive
  the report or enable ack.
- N02-read-navigation / dispose: armed `NativeReaderController` first-read
  hold, then navigation or unmount before release. Retirement cancels the
  capture future (outcome null) while the read stays held and busy until the
  test controller releases close. One selection/open/length/read/close,
  outcome null, no bytes/EOF/watchdog.
- Continuous no-write: `Directory.watch` plus inventory on the actual
  workspace/database; CAS/shelf were not configured and were not invented.
  Only SQLite `-shm` is excluded. Strace `-ff -ttt -yy` file/network is judged
  only inside the recorded baseline..observationEnd window. App PIDs (those
  that open the protected sqlite) had no off-loopback inet. flutter-test
  tooling DNS/probes (`10.0.0.2:53`, `169.254.169.254:80`, `198.18.0.1:443`)
  are recorded harness channels. Fresh Xvfb per profile.
- Debug integration executable hash is recorded separately from the frozen
  3.62 release artifacts. Debug JIT bundles have no `libapp.so`.

## Commands

- `flutter analyze` on the changed/new Dart files: no issues (`analyzer.log`).
- `dart format --output=none --set-exit-if-changed`: 0 changed (`format.log`).
- In apps/studio_demo: `flutter test test/import_native_lifetime_test.dart test/import_native_reader_test.dart`: 9 passed.
- `python3 tools/acceptance/run_skill_import_app_native_profiles.py`: all seven profiles passed (`profiles.json`, `official-runner.log`).
- `python3 -m unittest tools.tests.test_signed_import_native_profiles -v`.
- `python3 -m unittest tools.tests.test_acceptance`: unchanged 5 pass / 1 known failure.

## Deferred

Combined G1–G5 / full A6 / late C2 one-binary conditions remain open.
Distinct late-fixture binaries and independently qualified NG0–NG5 still do
not establish combined acceptance. NG0–NG3 were not rerun. L01 was not rerun.
Durable installation, cross-namespace import, production publisher roots,
production FTS/RAG, and device/model/provider/OS assistive-device/store
acceptance are not opened. I-037 stays partial; T-4/program unfinished.
Counts remain 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0. Project `user_version` stays 9.
