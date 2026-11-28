# Increment 3.62 — native prerequisite qualification (NG0–NG3)

Base `0b7ef6650b05c9897e48ec97f409bf2eb8f0f6d1` was clean on
feat/studio-foundation-20261125 and matched its tracked origin before editing.
This increment implements official native fixture bindings and independently
qualifies NG0–NG3 only. The seven N01–N02 profiles are not run or claimed.

## Independently verified scope

- Named `SkillImportHost.testImport` in the existing studio_demo App, with
  App-private lifetime registration and post-first-frame policy derivation from
  the actual workspace. Default construction still uses disabled policy, empty
  grants, and untrusted wall time. `apps/studio_demo/lib/main.dart` is unchanged.
- Separately compiled fixture entrypoint owns public seed/key/fingerprint,
  threshold/epoch 1, nowSeconds=1000, confidence true, empty grants.
- Test-only first-read controlled port forwards the actual capture guard,
  selected callback, and original future. Hold is the first read only.
- Three Linux release artifacts in `/workspace/skill-import-app-362` (not
  committed). `studio_demo` is the shared native runner; `lib/libapp.so` is the
  Dart AOT payload and differs for default, opt-in, and fixture. UTF-8 and
  UTF-16LE scans of compiled constants (public key, fingerprint, fixture data
  path) are fixture-only. Source comments are not compiled sentinels.
- Unit tests: 4 lifetime + 5 reader, all passed.
- Transport canaries: Directory.watch create/modify/restore/move/delete;
  strace 6.13 loopback file+connect; xdotool Tab/Return on an actual Flutter
  Linux window activates a test-only button and is not N01.
- Default and opt-in `--smoke-test` runs under strace recorded only local UNIX
  X11, Wayland, and session-bus endpoints. No remote network. Inherited
  `XDG_RUNTIME_DIR` is documented. This is a startup allowlist, not N-profile
  no-write evidence.

## Commands

- `flutter analyze` on the changed/new Dart files: no issues (`analyzer.log`).
- `dart format --output=none --set-exit-if-changed`: 0 changed (`format.log`).
- In apps/studio_demo: `flutter test test/import_native_lifetime_test.dart test/import_native_reader_test.dart`: 9 passed.
- Watch, strace, and keyboard canaries: passed JSON in this folder.
- `python3 tools/acceptance/run_skill_import_app_native_prereq.py`: three release builds and sentinel scans (`linux-builds.log`, `artifacts.json`).
- `python3 -m unittest tools.tests.test_signed_import_native_prereq -v`.
- `python3 -m unittest tools.tests.test_acceptance`: unchanged 5 pass / 1 known failure.

## Limits / next

N01–N02 remain pending. Combined G1–G5 and full A6 are not established; distinct
late-fixture binaries and this native seam do not close them. L01 was not rerun.
No real File/GTK/OS assistive-device, hardware/model/provider, production roots,
install, cross-namespace, FTS/RAG or store qualification. Recommended 3.63:
implement and independently qualify the seven native profiles using these
transports, without requalifying NG0–NG3 or older runtime rows. Counts remain
0 complete / 62 partial / 12 planned / 13 blocked; fullTasksCompleted=0, I-037
partial, T-4/program not done; original remainingAcceptance/remainingScope
unchanged. user_version=9, InversePatch=restoreSnapshot, LICENSE.core untouched.
