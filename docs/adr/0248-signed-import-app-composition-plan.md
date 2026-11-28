# ADR 0248 — Complete App selection / preview-consent composition planning

## Status
Accepted PLAN ONLY, Increment 3.49, under t155u; base
`68ebd8282f547e96b431fee17c2aa30cab30b83e`. Clean branch and matching origin tip
confirmed before editing. No UI/picker/App-host qualification is claimed.

## Gap and decision
ADRs 0245/0247 qualify bounded importer backends, not App source selection or UI
consent. Complete [App composition v1](../studio/spec/s8f-signed-import-app-v1.md):
- existing Linux/Web App owners and private standard-control composition, not
  guessed art-page widget APIs or a new product shell;
- trusted profile/current namespace/policy identity, empty default roots AND
  empty tool-grant sets, unknown clock stays untrusted, readiness before selection;
- exact maintained Linux selector source candidates and existing Web File APIs,
  bounded reads before capture, one operation/report, monotonic deadline and
  explicit late-completion/quiescence behavior;
- immutable literal presentation, unverified license facts/warnings, separate
  explicit App-owned one-use gesture, no installation/execution approval;
- generation/lifetime/staleness, safe local UI outcomes, no persistence/model/
  path/URL/JS-message selection or acknowledgment endpoint;
- independent actual App-host/source/chooser/widget acceptance, not old backend
  vectors relabeled as UI qualification.

## Exposed constraints, not invented workarounds
The current Linux shell has a path-based project inspection reader, no qualified
skill picker. The selected GTK plugin returns an XFile PATH, not an opened FD;
stat-before-open does not prove inode identity or race-free no-follow security.
The plan explicitly binds consent to immutable captured bytes/hashes instead.
No new FileToken, OS capability API or security attestation is invented.

The existing Web template contains a base tag, incompatible with inherited
base-uri 'none'; it was never the 3.48 standalone harness or a qualified App host.
The planned correction removes the tag and fixes same-origin absolute asset
roots; it does NOT relax base-uri or script integrity/CSP. Current documented
Flutter initialization supports local CanvasKit URLs and an engine style nonce.
App-only font/image/style permissions and strict worker/form/frame denial are
explicitly planned; the script policy is unchanged and no pack enters config.
The actual host must independently pass these exact bindings or report a conflict;
source inspection/third-party example CSP is not evidence of runtime feasibility.

## Why plan only
These bindings finish the exposed ownership/source/consent prerequisite. The
next coherent implementation slice includes a newly locked native selector,
bounded adapters, actual Flutter Web host/SRI/CSP, private App controls and new
Linux chooser/browser/widget evidence. No selector plugin, UI or host is installed,
implemented, executed or qualified in this plan increment. No frozen signed-import
contract conflict was found; do not invent around one in the next slice.

## Verification and preservation
New official Python plan/source/citation/status consistency checks, syntax and
diff checks only. All apps/packages/native files, dependency locks, previous
crypto/parser/privilege/format runtimes/tests, original remainingAcceptance and
remainingScope stay unchanged. Existing strict-equality test_acceptance failure
is untouched and not rerun/repaired. Historical plan checks are documentation
maintenance, not requalification of Increments 3.31–3.48.

Counts remain 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0; I-037, T-4 and overall program unfinished. Project
user_version=9; InversePatch=restoreSnapshot. No durable installation, cross-
namespace import, production roots/FTS/RAG, real-device/model/provider/store or
paid API acceptance, Mac/XS, excluded runtime/hardware or main merge opens.

Recommended Increment 3.50: first qualify the locked source adapters and actual
App-host CSP, then implement only this App selection/preview-consent composition
if those gates pass. Do not repeat backend/format qualification or call UI
acknowledgment an approval/install. Stop on an exact frozen-contract conflict.
