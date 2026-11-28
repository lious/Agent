# Increment 3.65 — official combined G1–G5 run

Base `113ea94fd84106d5d624f9885fe3dc530a2c8d15` was clean on
feat/studio-foundation-20261125 and matched its tracked origin before editing.
This increment executes the official combined G1–G5 run bound in Increment 3.64
and ADR 0263. It does not requalify N01–N02 or NG0–NG5, does not rewrite the
3.59/3.60/3.64 contracts, and does not set `fullA6AcceptanceComplete`.

## Combined qualification

A fresh disposable-cache G1 produced three release/CSP/source-map builds
(default `lib/main.dart`, ordinary opt-in `lib/main.dart`, and one isolated
late fixture targeting `test/import_late_phase_entrypoint.dart`). Input and
output SHA-256 are recorded in `artifacts.json`. Default and ordinary opt-in
contain none of the late entrypoint's public root fingerprint, release/observer
strings, gate markers, or test imports/source-map entries. The fixture artifact
is not deployable.

The fresh late fixture `mainSha256` is
`935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb`. That digest
is byte-identical to the historical 3.60 L02–L03 late hash because no
`apps/studio_web` source has changed since 3.60, and dart2js reproduced the
same bytes from a new disposable cache. This is a fresh G1 of the 3.65-base
inputs, not adoption of the historical 3.60 artifact path. The C2 binary is
the newly built `/workspace/skill-import-app-365/late-phase-app/main.dart.js`.
The digest does not equal the historical 3.59 L01 hash
`afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29`. Default and
opt-in mains also reproduced their 3.59/3.60 hashes; that is artifact-exclusion
reproducibility, not by itself a C2 claim.

All twelve C6 rows then ran in fresh browser contexts/stores against that one
fresh late main hash, with actual App/panel/factory/owner and trusted CDP
Tab/Enter on standard fixture controls. Already-qualified G2 (3.59 held-vendor
/ factory-observer) and G3 (3.60 controlled-reader arm/release/natural-null)
transports were reused, not requalified. Historical 3.59 L01 and 3.60 L02–L03
profile results were not borrowed as the combined rows. Per-row G5 records
actual CSP, vendor SRI, startup-only requests (request count unchanged after
composition start), IDB/localStorage/sessionStorage snapshot equality through
teardown, and zero component writes. CAS/shelf absence is proven by no such
API or path being supplied; those APIs were not invented. The reused drivers
still emit their historical `scope` labels; those labels are not the 3.65
acceptance claim.

`fullA6AcceptanceComplete` remains false. A passing combined G1–G5 run still
does not, by itself, set that flag. The official P5 A6.1–A6.7 audit remains
required. I-037 installation, production publisher roots, cross-namespace
import, and production FTS/RAG stay open. N01-semantics remains
framework-standard-semantics, not OS assistive-device qualification.

## Commands and outcomes

- `python3 tools/acceptance/run_skill_import_app_combined.py`: fresh G1 and
  twelve browser profiles, all passed (`runner.log`, `artifacts.json`,
  `combined.json`, per-case JSON under `results/`).
- `python3 -m unittest tools.tests.test_signed_import_combined -v`
- `python3 -m unittest tools.tests.test_signed_import_combined_plan -v`
  (frozen 3.64 binding checks still pass)
- `python3 -m unittest tools.tests.test_acceptance`: unchanged 5 pass / 1 known
  historical strict-equality failure; no acceptance assertion was rewritten.
- Python syntax compilation of the new runner and tests; Node syntax of the
  unchanged reused browsers; `git diff --check`.
- No Dart/runtime tree edits; no new analyzer/native compile/runtime
  acceptance claim beyond this combined web-fixture run.

Generated release artifacts remain in `/workspace/skill-import-app-365`; the
committed evidence does not embed compiled binaries or model packs.
LICENSE.core was not staged.

## Explicit limits / next

Increments 3.59–3.64 are still not, by themselves, combined G1–G5 or full A6
acceptance. This increment claims only the official combined G1–G5 run against
one fresh C2 binary. Next: the official P5 A6.1–A6.7 audit against recorded
evidence; do not set `fullA6AcceptanceComplete` unless that audit is honestly
complete. No real File/GTK/OS assistive-device, hardware/model/provider,
production roots, install, cross-namespace, FTS/RAG, or store-release
qualification. Acknowledgment never grants execution authority. Core/session/
capture/crypto, source deadline, project user_version 9, restoreSnapshot, and
LICENSE.core remain untouched. Counts remain 0 complete / 62 partial / 12
planned / 13 blocked; fullTasksCompleted=0, I-037 partial, T-4/program not
done; original remainingAcceptance wording unchanged.
