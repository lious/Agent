# ADR 0249 — Independently qualify the actual Flutter App-host CSP prerequisite

## Status and base
Accepted bounded prerequisite implementation, Increment 3.50. Clean feature
branch and tracked origin tip confirmed at
`5a02ca7ec6d8d5dbfd8bd1f530c3ca3f9872e922` before editing.
The [App composition plan](../studio/spec/s8f-signed-import-app-v1.md) / ADR 0248
is sufficient for this gate; no protocol conflict or new plan binding was needed.

## One coherent gate, not full composition
Implement and independently qualify ONLY A5's actual Web App-host prerequisite.
The remaining A3 source-adapter gates require a newly locked native plugin,
bounded native/browser source adapters and independent chooser/read evidence.
Those and the full selection/preview-consent UI are NOT folded into this host
security slice. The decision is not to label an incomplete source/UI gate passed.

The existing App index removes its base tag and uses the absolute root bootstrap
path. An App-owned custom Flutter bootstrap chooses main-realm CanvasKit and
absolute same-origin asset/entrypoint/renderer roots with no service-worker config.
The loopback qualification host builds the ACTUAL apps/studio_web/lib/main.dart
with release Dart-to-JS / --no-web-resources-cdn, then supplies per-response
CSPRNG style nonce, HTTP CSP and pre-execution SRI on the App/test bootstraps.
It does not substitute another App/main or invoke a new art-page widget API.

Inherited script policy, default-src 'none', connect-src 'self', object-src 'none'
and base-uri 'none' stay unchanged. Only the App-plan's style/font/image permissions
are added; worker/form/frame denial stays on. No unsafe-inline, unsafe-eval,
blob/data executable, CDN, security/certificate disable, alternate crypto source
or service worker. The exact existing sodium asset is hash-checked BEFORE serving
and retains its exact SRI. Existing backend startup is exercised only as a host
dependency smoke check, not old crypto/vector/importer qualification.

## Independent observed evidence
Six fresh real Chrome profiles use the actual compiled App:
- positive: first frame, actual Flutter view, nonce-bearing style, existing crypto
  bootstrap ready, no CSP violations/errors/failed or off-origin requests;
- tampered vendor SRI, missing vendor, intersected policy blocking vendor: App
  still renders, but backend startup fails and tampered code never executes;
- wrong/missing style nonce: actual engine inline styles are blocked by CSP;
  those profiles are NOT admitted as working host configurations.

A first-frame event alone is insufficient: the positive predicate also checks all
CSP/runtime/network/style invariants. In style-negative profiles the crypto
backend can still be ready; that does NOT make the broken App host admissible or
provide UI consent. No selection/acknowledgment UI exists in this slice to enable.
Screenshot evidence shows the existing App at revision 0, not a new import screen.
Existing project opening/IndexedDB writes are startup baseline, not new pack writes.

The static development host remains unqualified unless it supplies the exact
headers/SRI/nonce/asset profile. No production server, packaging/deployment or
publisher provisioning is implemented. Flutter's build-time Wasm dry-run output
is not Dart-to-Wasm runtime acceptance; the selected App executes Dart-to-JS.
No other browser/worker/device/GPU/model/provider/store qualification is implied.

## Preservation and next
All existing Dart sources, importer/crypto/schema/privilege/format runtimes/tests,
dependency locks and original acceptance/remainingScope remain unchanged. The
pre-existing strict-equality test_acceptance failure is untouched and not rerun.
New host integration tests, host evidence/preservation lint, Python/JS syntax,
actual App compile and App analyze are the only new verification claims.

Counts stay 0 complete / 62 partial / 12 planned / 13 blocked; I-037 partial,
fullTasksCompleted=0; T-4/program unfinished. Project user_version=9 and
InversePatch=restoreSnapshot unchanged. No source adapter/picker/UI acceptance,
installation, namespace transfer, production roots/FTS/RAG, paid APIs, Mac/XS,
excluded runtime/hardware work, main merge or deployment.

Recommended Increment 3.51: lock and independently qualify the bounded Linux GTK
and Web File source adapters under A3/A6; only after both source and host gates
succeed may full selection/preview-consent composition be implemented. Complete
any concrete new planning gap first under t155u, and stop on a frozen conflict.
