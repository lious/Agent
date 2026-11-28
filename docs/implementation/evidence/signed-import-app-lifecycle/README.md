# Increment 3.56 — actual-App B05–B08 lifecycle acceptance

Base: `c30441a71e0285bd597ac85c1fa7357822678c8a`, initially clean and matching
`origin/feat/studio-foundation-20261125`. Official bindings: App acceptance v1,
ADRs 0248/0250–0255. Concrete transport/gate plan supplements preceded their code.

## Recorded results (2026-11-28 Asia/Shanghai)

- 11 fresh actual compiled App browser profiles PASS: B05; B06 reload,
  away/back, disposal; B07 controlled-reading navigation and separately labeled
  synthetic handler-only pagehide; B08 real browser visibility and injected
  inactive/hidden/paused/detached framework notifications.
- B05 uses actual headed Chrome/GTK Escape, then three selections of the same File.
  Keyboard activation and real DOM/semantics state observe the private actual owner.
- Reload has a fresh realm/persisted=false. Away/back (including held read) actually
  restores the same realm/persisted=true in this run. No inferred BFCache claim.
  Lossless native User Timing/CDP Tracing preserves trusted old-realm pagehide.
- Held reader is FOUR CONTROLLED BYTES, not a File or crypto-success stub. It is
  bounded by the real capture path; pagehide retires the owner before release.
  Restored late completion observes exactly one open/read/completion/close, no
  report or acknowledgment capability. Synthetic pagehide is handler-only.
- Framework injections qualify only the framework observer boundary, NOT real OS
  lifecycle delivery. Actual tab visibility uses trusted browser events. Inactive
  retains the report; hidden/paused/detached retire it permanently after resume.
- All cases retain strict CSP, pre-execution vendor hash/SRI verification, actual
  readiness, repository/factory/owner/panel/store. No acknowledgment is invoked.
  Continuous component mutation/network observation and full storage snapshots pass.
  Normal navigation App startup writes/requests are explicitly separate (one normal
  startup write observed); this is not a claim that navigation never opens stores.
- Four release/CSP/source-map builds PASS: default, ordinary opt-in, lifecycle,
  held-reader. Public roots/fingerprint/lifecycle controls/test entrypoint are absent
  from both production-shaped artifacts; held reader exists only in its own build.
- Dart format and analyzer PASS. Seven new evidence/preservation static tests PASS.
  The unchanged historical acceptance suite remains **5 pass / 1 historical
  strict-equality failure**; its code and wording are untouched.

## Reproduce / provenance

`python3 tools/acceptance/run_skill_import_app_lifecycle.py` builds all four targets,
verifies artifacts/vendor before execution and runs ONLY new B05–B08 variants.
During harness development console delivery missed destruction-time pagehide;
`initial-build-and-transport-diagnostic.log` retains the original successful four
builds and failed transport attempt. Capture-phase lossless native tracing replaced
that insufficient observer; no event or security checks were waived. Final `runner.log`
is an all-pass fresh-profile rerun with `--reuse-verified-artifacts`, which checks
exact unchanged Dart/lock input and main/source-map SHA-256 before reusing those
four compiled targets. It still rechecks artifact exclusion and vendor integrity.
`artifacts.json`, `contract.json`, per-case JSON and `environment.json` bind evidence.
No old importer/crypto/format/host/adapter/widget/B01–B04 qualification suite reran.

## Limits / next increment

B09–B11 late-state/time and L01–L03/N01–N02 remain deferred. Recommend 3.57 for
B09–B11, officializing concrete gaps first. Full A6/I-037/T-4/program stay incomplete.
Counts: **0 complete / 62 partial / 12 planned / 13 blocked**, fullTasksCompleted=0.
Original remainingAcceptance/remainingScope, user_version=9, restoreSnapshot,
crypto/host/store/locks and LICENSE.core remain unchanged. No production roots,
installation, cross-namespace import, FTS/RAG, OS assistive-device, real device/model/
provider acceptance, paid APIs, deploy, Mac/XS, force-push or main merge.
