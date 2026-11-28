# ADR 0256 — actual-App late-state and trusted-time acceptance

Status: accepted Increment 3.57 plan before implementation.
Base: 2a137beb9ef088aaf855a343a7a3d3c56694c525, clean and matching origin.

Complete the concrete immutable-fixture/active-owner transport gap through the
normative 3.57 supplement in s8f-signed-import-app-acceptance-v1.md. Typed fixture
transition sequences are owned/applied by the actual App, never browser parameters
or a consent/backend endpoint. Private lifetime retirement precedes publication;
forward clock ticks alone do not retire. Test-only owner replacement changes the
actual in-memory project pointer, never persistent project identity or namespace.

B10 means existing signer eligibility expiry, NOT a new preview TTL/pack field.
The repository, not a fixture stub, refuses the real standard acknowledgment.
B09's eight alternatives, B10 and B11's three alternatives require twelve fresh
compiled-App profiles and three-artifact exclusion proof. Prior runtime and browser
qualification is neither rerun nor borrowed as new acceptance. L01–L03/N01–N02,
full A6, I-037, T-4 and program completion remain open. No production roots,
installation, cross-namespace import, FTS/RAG or device/model/provider/OS AT claims.

Contract citations: signed-import v1 S3 (signer notBefore/notAfter and trusted-time
recheck), S4 (preview acknowledgment is not authority); App v1 A4 (actual repository
acknowledgment refusal clears stale targets); acceptance v1 P2/P3 and the appended
3.57 transport supplement. These bindings do not add a TTL or modify the importer.

## Recorded outcome

All twelve fresh compiled-App B09–B11 profiles pass, with actual keyboard/File,
strict CSP/readiness, immutable report identities and no-component-write/storage
observation. B10's real repository refuses at notAfter=10000 after a valid tick
at 1001; no fixture-triggered forward retirement substitutes for acknowledgment.
Three release artifacts pass exclusion. See ../implementation/evidence/
signed-import-app-late-state/README.md. Full A6 and deferred rows remain open.
