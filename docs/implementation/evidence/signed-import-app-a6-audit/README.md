# Increment 3.66 — official P5 A6.1–A6.7 audit against recorded evidence

Base `0d1c66a8dacafc085681f47bdecb56fce7b206c2` was clean on
feat/studio-foundation-20261125 and matched its tracked origin before editing.
This increment performs the official P5 audit of row coverage and outstanding
A6.1–A6.7 obligations required before `fullA6AcceptanceComplete` may be set.
It does not re-execute B01–B11, L01, L02–L03, G3, the combined G1–G5 run, or
N01–N02/NG0–NG5, and it does not rewrite frozen 3.59–3.65 contracts. A passing
combined G1–G5 run still does not, by itself, set full A6; this audit is the
additional official closure check.

## Method

`python3 tools/audit/signed_import_app_a6_audit.py` reads committed evidence
only. It checks that every official P5 case ID has a recorded `passed=true`
result, that the 3.65 combined twelve C6 rows were served from the single
fresh C2 late hash
`935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb`, that the
seven official N01–N02 rows passed, and that each 3.61 A6.1–A6.7 remainder
has a later recorded closing citation. Historical 3.59/3.60 late hashes and
the frozen 3.65 `fullA6AcceptanceComplete=false` flag are left unchanged.

## Finding

P5 row coverage is complete for the official enumerated cases: 27 browser
profiles (B01–B11 as bound in 3.55–3.57), 12 combined L01–L03 C6 rows (3.65),
and 7 native N01–N02 rows (3.63). The 3.61 remaining A6 dispositions are
closed by recorded 3.62–3.65 evidence as cited in `audit.json`. No frozen
pass/fail conflict was found. `fullA6AcceptanceComplete` is therefore set
true in this increment's contract only.

This still does not close I-037. Completing these rows does not authorize
durable installation, production publisher roots, cross-namespace import,
production FTS/RAG, OS assistive-device qualification, manual OS-dialog
testing, desktop portals, device/model/provider, paid-API, or store-release
acceptance. B03 and N01-semantics remain framework/standard semantics.
L02–L03 remain controlled-port evidence, not real File. The 3.65 late hash
matching 3.60 remains a freshly built artifact, not adoption of the
historical 3.60 output path, and is not the 3.59 L01 hash.

## Commands

- `python3 tools/audit/signed_import_app_a6_audit.py --output docs/implementation/evidence/signed-import-app-a6-audit/audit.json`
- `python3 -m unittest tools.tests.test_signed_import_a6_audit tools.tests.test_signed_import_combined_plan tools.tests.test_signed_import_combined -v`
- `python3 -m unittest tools.tests.test_acceptance`: unchanged 5 pass / 1 known
  historical strict-equality failure; no acceptance assertion was rewritten.
- Python syntax compilation and `git diff --check`.
- No Dart/runtime tree edits; no new analyzer/native compile/runtime
  requalification claim. LICENSE.core was not staged.

## Next

I-037 remains partial; T-4 and the overall program stay not done. Counts
remain 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0. user_version=9 and `restoreSnapshot` unchanged.
Original remainingAcceptance wording is unchanged. Recommended next:
record residual I-037 / program leftovers without opening installation,
production publisher roots, cross-namespace import, or production FTS/RAG,
and without starting I-035, I-055, I-059, I-061, or I-016–I-019.
