# Increment 3.60 — controlled reader/release, L02–L03

Base e499a223995bf067edbf506bb8e45d681a5b8ad6 was clean and matched
origin/feat/studio-foundation-20261125 before editing. ADR 0259 and the
append-only late-plan witness supplement preceded implementation.

## Independently verified scope

Ten fresh strict-CSP compiled-App browser contexts: open/length/read crossed with
cancel/panel-disposal/session-context invalidation (nine L02); natural null while
close is pending then context invalidation (one L03). Actual common capture,
selected callback, live predicate and original outcome future are retained.
Source capacity remains occupied until one close and quiescence. Public trusted
keyboard controls arm/release only the controlled reader, never repository or
consent results. Re-arm, disabled selection, repeat release and root rebuild
cannot revive a report, acknowledgment or replacement selection. All browser
watchdogs remain unfired and durations below 15 seconds.

Three fresh release builds: default main, ordinary opt-in main, and the single
late-phase test entrypoint. Source maps/sentinels and frozen source digests prove
new controller/controls absent from both production entrypoints. Pinned sodium
bytes/hash/SRI are checked before execution. Every case records CSP, served hashes,
trusted keys, no exceptions/violations/chooser, unchanged IndexedDB/local/session
snapshots, zero component writes and zero accepted acknowledgment.
`heldReaderSentinelPresent` in artifact metadata is the legacy reader marker;
its false value is expected. The new `data-signed-import-late-reader` marker is
separately included in fixture sentinel checks.

## Commands and outcomes

- `python3 tools/acceptance/run_skill_import_app_late_reader.py`: fresh build and
  ten browser profiles, all passed (`runner.log`, per-case JSON, `artifacts.json`).
- In apps/studio_web: `flutter test test/import_late_reader_test.dart`: 6 passed.
- `python3 -m unittest tools.tests.test_signed_import_late_reader -v`: 7 passed.
- Dart analyzer on the five changed/new Dart files: no issues; formatter: 0 changed.
- Node syntax and Python compile checks passed; `git diff --check` passed.
- `python3 -m unittest tools.tests.test_acceptance`: unchanged 5 pass / 1 known
  historical strict-equality failure; no acceptance assertion was rewritten.

Environment executable digests, source hashes and three compiled hashes are
recorded. Generated release artifacts remain in /workspace/skill-import-app-360;
the small committed evidence does not embed model packs or compiled binaries.

## Explicit limits / next

L01 remains the frozen 3.59 dependency, not re-executed or expanded. G3 and the
ten new rows are independently qualified, not complete combined G1–G5/full A6.
N01–N02 are deferred. Next: audit cumulative acceptance coverage from frozen
evidence and complete native fixture bindings before implementing N01–N02.
No real File/GTK/OS assistive-device, hardware/model/provider, production roots,
install, cross-namespace, FTS/RAG or release qualification. Acknowledgment never
grants execution authority. Core/session/capture/crypto, source deadline, project
user_version 9, restoreSnapshot, and LICENSE.core remain untouched. Counts remain
0 complete / 62 partial / 12 planned / 13 blocked; fullTasksCompleted=0, I-037
partial, T-4/program not done; original remainingAcceptance/remainingScope unchanged.
