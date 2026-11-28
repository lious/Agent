# ADR 0247 — Independently qualify bounded Web signed import-to-preview

## Status and base
Accepted implementation record, Increment 3.48. Clean branch and origin tip
confirmed at `462b0a25a02c14be6fb9019c6ddeec0a50525629` before editing.
The completed 3.47 [Web plan](../studio/spec/s8f-signed-import-web-v1.md) and
[ADR 0246](0246-web-signed-import-composition-plan.md) were sufficient. No frozen
contract conflict or new protocol was introduced; those plans remain unchanged.

## Decision
Implement the exact same-origin libsodium.js 0.8.4 artifact, retained ISC licenses,
pre-packaging SHA256/SHA384 checks, and runtime SRI BEFORE execution under W2 CSP.
An App-owned classic bootstrap owns its private readiness Promise and frozen
bridge. Secure context/CSPRNG, 10000 ms monotonic deadline, captured API/version,
RFC positive and canonical-S/small-order startup negatives precede publication.
Failed readiness, integrity, CSP, wrong symbol/type/version, replacement or page
teardown are terminal; late callbacks cannot revive or mint a repository.

The typed `dart:js_interop` final adapter double-copies Uint8Array bytes; strings,
shared/resizable buffers, truthy returns and exceptions are not cryptographic
success. It validates key and R points and exact complete DSSE PAE, never a JSON
rewrite or `signed=true`. Conditional concrete backends retain the native source
and native artifact policy unchanged and provide a terminal unavailable target.
Native entry/test imports route through the conditional seam solely to preserve
concrete-type identity during static analysis; no native algorithm, test assertion
or behavior changed and no Linux runtime was requalified. Availability guards at
import/ack prevent empty-root unsigned use after Web backend failure as well.

The separate opt-in `studio_signed_skill_import_web.dart` factory returns only
after self-tests. The App snapshot callback remains live after await. Shared
`studio_assets.dart` remains untouched. Build-time AppProfile pinned publisher
policy, distinct-key threshold, zero default roots, namespace/time/grant checks,
immutable realm-local reports and UI-owned one-use acknowledgment stay inherited.
Acknowledgment writes no document and grants no execution/tool approval. No UI,
file picker, publisher provisioning, installation or persistence was added.

## Independent evidence, not native inference
`tools/acceptance/run_signed_import_web.py` verifies pinned hashes BEFORE running
code, compiles the ACTUAL importer using `dart compile js -O2`, then uses fresh
real Chrome processes under actual SRI/CSP. First production-bridge RFC8032 tests
1–3, explicit canonical/S+L/small-order/length negatives, all 210 pinned Wycheproof
subcases, mutation isolation and frozen bridge; then the actual compiled importer.
An additional mutating-upstream test realm repeats those 210 subcases; there are
210 UNIQUE corpus vectors, not 420 distinct vectors. No Node/VM/FFI results stand
in for browser qualification. Deterministic public signed fixtures are generated
offline with Python cryptography, not the native Dart FFI fixture helper.

The browser importer covers exact signed bytes/tampering, two-key threshold and
duplicates/keyids, empty roots and no invalid-signature downgrade, strict encoding,
path/hash/schema/work/size/precision bounds, unverified license warnings, fresh
state across first asynchronous initialization, immutable consent and staleness.
Separate realms cover before-ready, foreign/replaced bridge, symbol/version/type,
CSPRNG, SRI/CSP rejection, exact deadline, late callback, string/shared/resizable
rejection, API exceptions and teardown. Storage calls and unexpected loopback
requests are asserted absent; CSP disallows off-origin App connections/executables.

Evidence records browser/compiler versions, mode and executable digests. Only
Dart-to-JS main browser realm in that Chrome test-host profile is qualified; the
combined JS/WebAssembly artifact's internal execution path is NOT asserted.
Neither all engines nor Dart-to-Wasm, workers, physical devices, models, providers,
paid APIs, security audit or production/store acceptance is claimed.

## Preservation and next
I-037 remains partial; counts 0 complete / 62 partial / 12 planned / 13 blocked,
fullTasksCompleted=0; T-4/program unfinished. Original remainingAcceptance and
remainingScope strings are preserved; only explicit scope/evidence appends record
this Web profile. Project user_version=9 and InversePatch=restoreSnapshot remain.
Existing strict-equality acceptance failure is untouched; this is not a repair or
requalification of Increments 3.31–3.47.

Defer UI/file-picker wiring, production publisher roots, installation, namespace
transfer, production FTS/RAG and all standing excluded runtimes/hardware claims.
Recommended Increment 3.49: complete the already-listed App file-selection /
preview-consent composition PLAN under t155u, binding existing App ownership and
opaque one-use consent without inventing art-page widget APIs. Do not start UI
implementation until those official contracts suffice, or infer persistence/
provisioning permission. If that plan cannot bind cleanly, select another distinct
already-planned leftover; do not repeat the Linux/Web/format runtime qualification.
