# Increment 3.49 — App composition planning evidence only

Base: `68ebd8282f547e96b431fee17c2aa30cab30b83e`; clean
feat/studio-foundation-20261125 matched its tracked origin tip before editing.
Plan: `docs/studio/spec/s8f-signed-import-app-v1.md`; decision: ADR 0248.

## What was completed

The official prerequisite binds existing Linux/Web App ownership, trusted current
profile/namespace/policy/grants/clock, readiness-before-source-selection, one
bounded source operation and one report, immutable literal presentation, separate
App-owned opaque one-use acknowledgment and independent actual App-host/UI tests.
It preserves DSSE/Ed25519, no invalid-signature downgrade, signed=true not evidence,
empty roots and zero execution/tool approval. No original acceptance is reduced.

`contract.json` records the plan limits and preserved source trees/files.
`sources.json` records exact Linux selector/transitive candidates and archive
hash verification, read-only code inspection hashes and existing locked dependency
pins. No downloaded package source was executed; no package was installed or lock
resolved. These are source/provenance facts, NOT file-picker or UI qualification.
The compatible cross_file candidate is 0.3.5+5, not incompatible latest 0.4.0.
The selector interface's HTTP dependency is NOT a URL/source retrieval permission.

Two important bindings prevent accidental overclaim:
- GTK returns an XFile path, not an atomic opened capability. Consent binds the
  captured bytes/hashes; no inode identity/race-free no-follow claim is made.
- Current Web index has a base tag; it is not the qualified standalone backend
  harness. Planned App hosting removes that tag, retains base-uri 'none'/all
  inherited script CSP/SRI, self-hosts renderer assets and uses documented engine
  style nonces. Actual host qualification is required; unsupported behavior fails
  rather than relaxing security or inventing another app shell.

## Checks run

```
python3 -m unittest tools.tests.test_signed_import_app_plan tools.tests.test_signed_import_web_runtime tools.tests.test_signed_import_web_plan tools.tests.test_signed_import_runtime_contract tools.tests.test_signed_import_plan
python3 -m py_compile tools/tests/test_signed_import_app_plan.py
git diff --check
```

34 Python documentation/source/fixture-preservation checks pass (9 new App-plan
checks). These do not run old native/browser importers, crypto/vector suites,
format-repair or device/model/provider tests. Python syntax and diff checks pass.
No Dart source changed, so no Dart/Flutter UI runtime/static acceptance is implied.
The pre-existing strict-equality test_acceptance failure remains untouched and was
not rerun or repaired. Prior baseline evidence remains unchanged.

## Landing boundary / next

PLAN ONLY. New selector locking, bounded platform adapters, actual Flutter App
host/SRI/CSP and independent GTK/browser/widget integration form the next coherent
implementation slice; no UI/source/host qualification is folded into these plan
checks. Existing backend qualification is not relabeled as that missing evidence.

Counts unchanged: 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0. I-037, T-4 and program unfinished. Original remainingAcceptance
and remainingScope unchanged; only a plan-only scope/evidence append. All apps,
packages, native source and dependency locks unchanged. Project user_version=9 and
InversePatch=restoreSnapshot unchanged.

Recommended Increment 3.50 first qualifies the selected bounded sources and actual
App-host CSP, then implements only this planned App preview/consent composition if
those gates pass. No production roots, installation, namespace transfer, FTS/RAG,
paid APIs, deploy/main merge, Mac/XS or standing excluded runtime/hardware work.
