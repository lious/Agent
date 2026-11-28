# 8F supplement — Web signed import-to-preview composition v1

Status: official PLAN ONLY, Increment 3.47, under t155u. This completes exposed
Web bindings from ADR 0245. No browser backend, bridge, loader or Web importer is
implemented or qualified by this increment. Implementation is the next slice.
The [base verification plan](s8f-signed-import-v1.md) and ADRs 0244/0245 remain
normative: exact DSSE bytes, Pure Ed25519, distinct pinned keys, bounded schemas,
immutable preview/acknowledgment and zero execution authority. Native Linux
results do NOT qualify Web. No different Web signature protocol is introduced.

## W1 — one locked browser artifact, not floating imports

Select libsodium.js **0.8.4**, ISC, combined classic browser sumo distribution:
`dist/browsers-sumo/sodium.js`. Sumo is needed for strict point validation.
Candidate source URL, byte count, SHA256, SHA384 SRI, license, source submodule
and expected core version are recorded in
`docs/implementation/evidence/web-signed-import-plan-v1/backend-candidate.json`.
Exact candidate byte count: 1319027. SHA256:
`5d6f10ef3e530b45536ee0aa40fa54a46220cc78984df6992a9d48e9a741e8f7`.
Exact SRI:
`sha384-mMeApJgV3qm7BJusi9ualkYZcdoTJBRsmYEZdzYa+yNWz+UH12DXh6SwImc6IO2V`.
The 0.8.4 source submodule 33cc75ab1565d9dcbe808354191bd572ad6b64d0 declares
libsodium 1.0.22 in configure.ac. That is provenance, not runtime verification.

Build preparation must copy these EXACT bytes into an App-owned immutable
same-origin vendor asset at `/vendor/studio-signed-import/sodium-0.8.4-sumo.js`,
checking both hashes before packaging and retaining
ISC copyright/license. No minifying, rebundling, Unicode conversion or substitutions
after locking. An independently rebuilt/replaced artifact requires a new explicit
lock and fresh qualification, not accepting a matching version string alone.
Do not resolve npm's floating `libsodium-sumo:^0.8.0` at runtime. This chosen
single-file distribution contains its own JS/WebAssembly implementation; no
unlocked secondary executable asset is permitted. Any unexpected executable
fetch/dependency discovered in qualification is a failure of this profile, not
permission to add a CDN, blob script or relaxed trust rule.

Use a dedicated, opt-in Web entrypoint. No UI/file-picker wiring, runtime package
installer, model-selected URL, CDN, dynamic import map, pack-controlled path,
remote public-key lookup or service-worker asset replacement is introduced.
Runtime loading is only the App's exact predeclared same-origin vendor asset.

## W2 — integrity BEFORE execution, CSP and readiness

Trusted App bootstrap loads the classic script with the locked SHA384 integrity
attribute. Browser SRI MUST succeed before any vendor code executes; verifying
fetch bytes AFTER script execution is not integrity enforcement. Cached assets
must still match integrity. Failed integrity, load error or CSP refusal is
SKILL_IMPORT_POLICY/backend, with no repository or verified report published.
There is no fetch-then-eval, Function constructor, unsigned retry, alternate URL,
Blob/data-URL loader or retry with unsafe-eval as an escape hatch.

For this CLASSIC distribution, the upstream documented interface is
`window.sodium={onload(sodium){...}}` installed by trusted bootstrap BEFORE the
vendor script. Do not confuse that callback with the ESM package's `.ready`
Promise. The App shim turns the callback into its own private readiness Promise.
Reject an unexpected pre-existing sodium/global bridge instead of adopting it.
Do not expose a public factory accepting an arbitrary JSObject or ready=true.

Initialization state is exactly uninitialized -> loading -> ready OR failed.
One bootstrap generation has a 10000 ms monotonic readiness deadline. Load,
callback/API/self-test failure, deadline or realm teardown makes it terminally
failed; late callbacks cannot publish a backend or revive that generation. A
new App composition root may explicitly start a new generation, never a pack.
Do not queue import tokens while waiting. The asynchronous factory returns a
concrete verifier/repository ONLY after readiness and self-tests; importPack and
acknowledgment then retain their synchronous, current-App-snapshot semantics.

Qualification must use the actual intended CSP, at least: default-src 'none';
script-src 'self' plus the approved script hash and 'wasm-unsafe-eval'; connect-src
'self'; object-src 'none'; base-uri 'none'. The bootstrap/test code must itself be
App-owned/allowed; inline scripts need their own fixed hash, not unsafe-inline.
No unsafe-eval is authorized. If the combined artifact's fallback cannot run
under that policy, initialization fails closed. This profile qualifies the pinned
combined JS/WebAssembly artifact and observed browser path, not a promise that
WebAssembly was used or that every fallback/engine is supported.

Require a secure context and browser crypto.getRandomValues for preview nonces;
unknown/absent CSPRNG is backend-unavailable, never Math.random. No global CSP,
network or certificate checks may be disabled to make a test pass.

## W3 — concrete Dart adapter and realm-owned byte boundary

The current importer imports a final native SodiumVerifier directly. Refactor
ONLY that import seam to a conditional backend export, keeping the ordinary
shared studio_assets entrypoint and native entrypoint behavior unchanged:
- IO target -> existing native SodiumVerifier implementation;
- dart.library.js_interop -> final Web SodiumVerifier implementation;
- unsupported target -> unavailable final implementation, never a permissive fake.
Each concrete type keeps private construction; no public injected bool-returning
verify callback, generic fake provider or caller-supplied JS capsule is accepted.
The Web entrypoint must contain no reachable dart:ffi/dart:io/native loader.
Native source/artifact policy stays unchanged; source-preservation checks are
not a new Linux qualification. No native runtime tests are counted as Web tests.

Web factory initialization is asynchronous; the published methods remain
validPublicKey(key)->bool and verify(message,signature,key)->bool. After callback,
require sodium_version_string()==`1.0.22`, the two exact functions below and
expected public-key/signature lengths. Run startup RFC positive and
canonical-S/small-order negative self-tests through the captured functions.
No repository is published if a symbol, type, version or self-test fails.

Use typed dart:js_interop members, not string-evaluated calls/dynamic unsafe
property lookups. The App shim captures function identities bound to the approved
sodium object, retains its capsule in a private closure and freezes its exposed
shape. Reject known bridge/global replacement or a mismatched bootstrap generation.
This assumes trusted App origin/bootstrap, like trusted native deployment; it is
NOT an XSS defense, remote attestation or proof against a compromised same-origin
script. A forged object with a matching module name/version is not provenance.

All bridge parameters must be freshly copied Uint8Array values, never strings,
JS Array coercions, UTF-16, shared/resizable buffers or views into retained token,
PAE, signature/key or report data. Do not rely on whether a particular .toJS
conversion happens to share backing storage. Both Dart and shim copy before
upstream calls; mutation of JS inputs cannot mutate retained evidence.
Use exactly:
- crypto_core_ed25519_is_valid_point(key32), and likewise signature.slice(0,32);
- crypto_sign_verify_detached(signature64, COMPLETE_PAE, key32).
Order matters: the JS signature argument comes FIRST, unlike the Dart method.
Only a strict boolean true is success; false is invalid, not a truthy numeric
value/string. Unexpected return types or JS exceptions mean backend failure,
not unsigned success, license warning or a different verifier fallback.

Do not call upstream permissive string/base64 helpers for pack admission.
Dart's strict decoder and exact raw-byte DSSE framing remain authoritative.
Expose no signing, eval, key enrollment, shader/model loading, filesystem,
network-tool or approval-minting function through the crypto bridge.

## W4 — AppProfile, time, consent and failure ownership

Publisher keys, namespace, policy epoch, threshold and scope stay in the existing
trusted build-time Dart AppProfile composition record, NOT JS package metadata,
window messages, localStorage, IndexedDB, a selected pack or model output.
Default publisher roots remain EMPTY. Keyid is only an unauthenticated hint.
Actual production publisher provisioning is outside this slice.

Resample the trusted App snapshot at import time AFTER asynchronous backend
initialization; do not reuse a pre-await policy/clock/grant snapshot. The App's
installed policy object must still be identical to the import argument. An import
never waits across another initialization step. Acknowledgment rechecks current
policy, scope, time, expiry/revocation and retained hashes exactly as native v1.
No App state drift during readiness is silently approved.

Unknown clock is needsReview, not verified; invalid signed input never downgrades.
One-use ImportUserActionPort remains owned only by trusted App UI composition.
A JS callback, ready Promise, model echo, message event or signed=true cannot mint
consent or become an ApprovalReceipt. No product UI is added here. Preview and
acknowledgment remain in-memory, realm-local, immutable, documentWrites=0 and
executionAuthority=false. Navigation/reload loses pending previews; do not persist,
replay, postMessage or transfer them to workers/other tabs/App namespaces.

All inherited byte/depth/file/signature/schema-work/pending-preview bounds remain.
If the Web backend is unavailable, this factory publishes no repository, even
for unsigned input. It must not silently route a failed signed import through
an existing privilege-only knowledge preview path. The separate explicit unsigned
knowledge allowance is unchanged; this is no new installation path.

License declarations stay unverified facts/risk warnings under s1a/s1c. Integrity,
CSP, cryptographic backend, clock, privacy and capability failures are independent
non-license gates, not opportunities to erase facts, auto-grant tools or retry
through another provider. No browser storage, production FTS/RAG or upload occurs.

## W5 — host JSON semantics without weakened precision guards

The JS-compiled Dart decoder must retain the existing strict lexical duplicate,
Unicode/BOM, base64 and finite decimal-roundtrip guards. Signed original bytes
are never normalized to make them pass. Native's 64-bit int implementation is
not a Web numeric guarantee. For example, a raw 9007199254740993 lexeme must be
refused on a JS number decoder that rounds it, rather than accepted as a nearby
const/enum value. Time integer strings remain unchanged. Do not assert that all
native-accepted numeric inputs are Web-accepted; the base plan already limits
numbers to each selected decoder's lossless roundtrip. Do not silently widen
that contract or rewrite previous native tests to manufacture parity.

Keep the same authoritative FilmSkill closure, local manifest metaschema,
permission-diff bytes, distinct raw-key count and immutable report constructor.
No Web copy of an invented looser schema or independent privilege compiler.

## W6 — required independent browser evidence (NOT RUN in 3.47)

1. Verify the exact candidate hashes, retain ISC license, then execute the pinned
   artifact in a REAL browser under the intended CSP. Record browser version,
   Dart compiler/mode, JS wrapper/core version and artifact digests. Node/VM,
   native FFI, API symbol presence or an intercepted stub are NOT Web evidence.
2. Run RFC 8032 vectors, S>=L/S+L, canonical/small-order public-key and R negatives,
   wrong lengths and all 210 already-pinned Wycheproof subcases through the WEB
   bridge. Count corpus subcases separately from framework cases. Tests must
   prove absence of string coercion, truthy returns and input-buffer aliasing.
3. Compile the actual importer to browser JS and exercise signed DSSE fixtures,
   tamper, two-key threshold/duplicates/keyids, empty roots, unsigned vs invalid
   signed, strict encodings/duplicates/paths/hash/schema/resource limits, license
   warnings and numeric precision. Use checked-in deterministic public fixtures
   prepared offline; do not import the native FFI signing helper into browser tests.
   Tests cover exported repository behavior, not only standalone JS crypto calls.
4. Test before-ready rejection, unavailable symbol/wrong version, SRI tampering,
   CSP failure, rejected/never-resolving readiness, the exact deadline, late
   callback after failure, foreign/replaced capsule, CSPRNG absence, clock/grant/
   policy drift across init, unsigned no-root behavior and immutable consent.
   Fault injection stays in a TEST harness, never a production fake-verifier API.
5. Assert zero document writes/execution authority, no automatic approvals,
   persistence, publisher fetch or unexpected executable/network fetch. Simulate
   host mutable bytes/JS views and navigation/discard/stale acknowledgment.

Use a Dart browser test suite against a loopback-only trusted test origin; it may
serve these public assets, not deploy production. Tests require a real browser
and exact asset—no skip or fake-success fallback. Record failures as failures;
unsupported CSP/engine is not a reason to relax checks. Static browser-JS compile
and analyze are also required. This initial evidence target is Dart compiled to
JavaScript in the main browser realm, not Dart-to-Wasm, workers or other engines. No Flutter widget/file-picker, Safari/iOS/Mac/XS,
physical device, inference/model, provider, paid API or store acceptance is implied.

## W7 — sources and landing boundary

Sources read 2026-11-28 (Asia/Shanghai):
- https://raw.githubusercontent.com/jedisct1/libsodium.js/0.8.4/README.md
- https://raw.githubusercontent.com/jedisct1/libsodium.js/0.8.4/Makefile
- https://api.github.com/repos/jedisct1/libsodium.js/contents/libsodium?ref=0.8.4
- core configure.ac URL in backend-candidate.json
- https://dart.dev/interop/js-interop/usage
- DSSE/RFC sources and authoritative s8f/s8g/s1a/s1c links in the base plan.

These bindings complete the missing Web composition prerequisite. The source pin
and plan checks do NOT qualify downloaded executable code. This increment lands
PLAN ONLY because trusted pre-execution bootstrap, a concrete cross-target seam,
and independent browser crypto/import test infrastructure form the next coherent
security-sensitive implementation slice. No protocol conflict was found; do not
invent around one if implementation later exposes it. I-037/T-4/program stay
unfinished; user_version=9 and InversePatch=restoreSnapshot remain unchanged.
