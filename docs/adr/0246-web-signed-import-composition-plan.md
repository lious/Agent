# ADR 0246 — Complete the Web signed-import composition prerequisite

## Status
Accepted PLAN ONLY for Increment 3.47 under t155u. Base f627ce3.
No browser executable, native qualification or Web acceptance is claimed.

## Gap and decision
ADR 0245's Linux service has a final native verifier and no browser bootstrap,
interop boundary or browser evidence. It cannot be relabeled as Web support.
Adopt [Web composition v1](../studio/spec/s8f-signed-import-web-v1.md), linked
from s8f and the base signed-import plan. The seven bindings specify:

- exact libsodium.js 0.8.4 combined browser artifact/hash/SRI and source core
  provenance 1.0.22, with no floating runtime dependencies;
- same-origin App-owned script, SRI BEFORE execution, intended CSP, documented
  classic onload callback, a terminal 10000 ms readiness deadline, no late revival;
- a conditional concrete final Dart backend seam, copied typed byte arguments,
  strict point/Ed25519 calls/booleans and no arbitrary injected JS verifier;
- installed AppProfile/policy identity, empty default roots, fresh App snapshot
  after await, CSPRNG, immutable realm-local consent and no authority grants;
- inherited decoder/precision semantics, not false native/Web numeric parity;
- independent REAL-browser crypto/import/failure/CSP evidence, not VM/Node/FFI
  results or source symbol inspection.

Candidate source bytes were downloaded only to calculate hashes and inspect
source. Source/tag/submodule/version evidence and hashes are in
`evidence/web-signed-import-plan-v1/backend-candidate.json`. No candidate code
was executed, vendored as a runtime, installed, deployed or qualified.
No published wrapper compatibility list is counted as our browser acceptance.

## Why separate implementation
Trusted pre-execution bootstrap, the concrete cross-target seam and browser test
infrastructure comprise the next coherent security-sensitive implementation
slice. Finish this implementable prerequisite first rather than rushing those
changes into the same plan commit. No frozen-contract conflict was found. If
actual CSP/backend behavior later conflicts, fail closed and report it; do not
invent a weaker crypto scheme or relax the controls.

## Verification and preservation
New official Python plan-consistency tests and Python syntax/diff checks only.
No Dart/native crypto/import/model/device/provider runtime is rerun or claimed.
Native source/artifact policy, original acceptance and remainingScope strings,
privilege model, frozen I-036 assertions, Project user_version=9 and
InversePatch=restoreSnapshot are unchanged.

The 3.46 documentation-only status lint now reads its historical 3.46 status
snapshot instead of freezing future progress. Its runtime tests and protected
source checks remain unchanged; this is not new native qualification. The old
strict-equality test_acceptance failure and its wording remain untouched.

## Progress and next
I-037 remains partial. Counts 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0; T-4/program remain unfinished. Web implementation, UI/file-
picker wiring, production publisher roots, durable installation, cross-namespace
transfer and production FTS/RAG remain unopened. No paid APIs or production deploy.

Increment 3.48: implement this pinned Web bootstrap/adapter and qualify it with
independent browser tests, first RFC/negative/Wycheproof and then the actual
compiled importer. Do not requalify Linux or infer real-device/provider support.
