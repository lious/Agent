# Increment 3.64 — combined G1–G5 / late C2 same-binary binding only

Base `79109119861569d1b32093f8ba2f0ad67f7ba58d` was clean on
feat/studio-foundation-20261125 and matched its tracked origin before editing.
This increment officializes the combined-acceptance binding under t155u. It does
not execute a combined G1–G5 run, requalify N01–N02 or NG0–NG5, or rerun L01,
B01–B11, L02–L03, or G3. Combined G1–G5 and full A6 are not claimed.

## Finding

The official late C2 same-binary condition (late v1 C2:58–66) and C7 combined
gates (C7:190–212) are already specified and are not met. The 3.61 audit, still
authoritative, recorded two distinct late-fixture main hashes:

| Slice | Qualification commit | Late fixture `mainSha256` |
| --- | --- | --- |
| L01 (3.59) | e499a223995bf067edbf506bb8e45d681a5b8ad6 | `afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29` |
| L02–L03 (3.60) | 7c616a4aab245505f3fdd9fac15095fd640f5e3b | `935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb` |

L01 observer-method byte identity and independently qualified G2, G3, NG0–NG5,
and N01–N02 rows do not establish that one binary or combined C7 evidence.
3.59 and 3.60 contracts already leave `allLateRuntimeGatesComplete` and full A6
false. No studio_web source has changed since 3.60, so the current late
entrypoint already contains both late transports; that still does not make
either historical late hash the C2 binary. No contradictory frozen evidence
requires reopening earlier rows in this increment.

## Official combined run (next increment)

A later increment must take a fresh G1 (default, ordinary opt-in, and one
isolated late fixture) from frozen inputs, then independently qualify all twelve
C6 rows (G4) plus per-row G5 observations against that single new late main
hash. Historical 3.59/3.60 contracts stay frozen. B01–B11 and N01–N02 are not
rerun unless a genuine conflict appears. A passing combined G1–G5 run still does
not automatically set `fullA6AcceptanceComplete`; P5 A6.1–A6.7 audit remains
required, and I-037 installation/publisher/cross-namespace/FTS/RAG stay open.

## Commands

- `python3 -m unittest tools.tests.test_signed_import_combined_plan -v`
- `python3 -m unittest tools.tests.test_acceptance`: unchanged 5 pass / 1 known failure
- Python syntax compilation of the new test and evidence loader
- No Dart/runtime changes; no new analyzer/native compile/runtime acceptance claim

Counts remain 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0; I-037 partial; T-4/program unfinished. user_version=9 and
`restoreSnapshot` unchanged. LICENSE.core was not staged.
