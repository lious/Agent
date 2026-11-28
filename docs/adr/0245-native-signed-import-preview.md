# ADR 0245 — Executable bounded signed import-to-preview, native DEV port

## Status and scope
Accepted for Increment 3.46 after ADR 0244 and s8f-signed-import-v1.md.
Base: 2d7c9a95111aaf9edc2075edb8a98acf3124c611.
This is a tested Linux x86_64 native service, NOT UI/file-picker wiring,
production publisher provisioning, durable installation or Web qualification.
I-037 stays partial. Existing privilege-only fields are not cryptographic proof.

## First qualify the maintained backend
Locked libsodium 1.0.22, ISC, official versioned 2 MiB source archive SHA256 in
`packages/studio_assets/third_party/sodium/backend-lock.json`. Source, API,
license, DEV binary digest and reproduction instructions are retained there.
The native loader checks trusted deployment artifact SHA256 and runtime version;
there is no discovery, algorithm negotiation or runtime download/install path.
Deployment must keep the binary immutable; no compromised-host/race defense is
claimed. This lock is a qualified DEV build, not a reproducible-build assertion.

Pure Ed25519 uses maintained `crypto_sign_verify_detached`, with canonical
prime-subgroup public-key/R validation by `crypto_core_ed25519_is_valid_point`.
No curve arithmetic or custom point blacklist was written. The first backend
checks (RFC 8032 vectors and explicit negatives) passed before importer work.
A transcription error in RFC vector 3 was corrected against the RFC, not hidden
by weakening verification. The final backend suite has 7 framework cases: RFC
vectors 1–3, S>=L/S+L, malformed/canonical/small-order/length/artifact-pin negatives,
and ONE case covering all 210 pinned C2SP Wycheproof public verification subcases.
No user/private publisher key is used; local signing helpers live only in tests
and use publicly specified deterministic fixture bytes.

## Implemented boundary
The opt-in `studio_signed_skill_import.dart` exports FilmSkillRepository and
its native backend. The existing shared studio_assets entrypoint is unchanged,
so this new dart:ffi port is not silently imported into Web/shared code.

- `importPack(token, namespace, signaturePolicy)` captures bounded selected bytes,
  accepts only the identical installed App policy object, binds existing AppProfile
  and App namespace, and verifies exact DSSE 1.0.2 PAE with distinct raw-key
  threshold. keyid/envelope extras never choose authority. Invalid signed packs
  never downgrade to unsigned; the default App policy has no publisher roots.
- Strict preflight refuses duplicate/escaped-alias keys before map decoding,
  invalid UTF-8/scalars/BOM, trailing JSON, nonfinite/lossy numeric lexemes and
  malformed/noncanonical base64. Both DSSE alphabets and padding forms work.
  Tests caught that Dart's UTF-8 decoder strips BOM; explicit byte preflight now
  refuses it at every JSON layer. Authenticated bytes are never reserialized.
- Exactly three whitelisted files are bounded/hash-checked, never extracted.
  The unchanged authoritative s8g FilmSkill reference closure is embedded, with
  a closed local manifest-schema metaschema. Required package/schema/fixture
  fields, identities, namespace, fixture closure, numeric/enum/time slots and
  step declarations/DAG are checked. Fixtures are data: none is executed.
- Reports are deeply immutable and importer-owned. Retained bytes, exact local
  permission-diff bytes/digest, hashes, namespace, policy epoch and scope are bound
  behind a fresh 128-bit CSPRNG preview ID. One-use acknowledgment requires a
  capability minted by the trusted App UI after consent, not a boolean/ID echo.
  It rechecks current policy/scope/time, expiry/revocation and immutable hashes.
- Unsigned knowledge remains untrusted; unknown/rollback clock is needsReview,
  never verified. Missing tools are displayed, not granted. License declarations
  remain unverified facts/warnings under s1a/s1c, not grants or extra license
  approval. Every preview/ack has documentWrites=0 and executionAuthority=false.

## t155u implementation-exposed plan supplements
Before their safeguards were added, the official supplement was appended with
bounded schema work (200000 visits/comparisons per operation), max 16 pending
previews, a UI-owned one-use gesture binding, and later strict numeric precision
refusal. RFC 8259 §6 permits numeric range/precision limits. This avoids silently
merging const/enum values through host floating-point rounding; it does not
invent a general/arbitrary-precision schema engine. Maintained backend subgroup
checks and native-only qualification boundaries are explicit. No frozen source
schema or existing privilege contract is rewritten.

## Evidence and static checks
`docs/implementation/evidence/i037-signed-import-preview/`:
- 90 new Dart framework cases: 7 backend + 83 importer. Wycheproof's 210 subcases
  are NOT added again to the framework-test count.
- 4 new Python contract/preservation checks; source schema closure matches s8g.
- `dart analyze` for the whole assets package: no issues.
- Changed Dart files pass format check; Python syntax and git diff checks pass.

The historical 3.45 plan lint now compares its status-only assertion with the
3.45 commit, not all future runtime progress. Its original plan snapshot and
privilege/frozen-file checks remain. This is documentation-regression maintenance,
not requalification of 3.45. The separately documented old acceptance suite's
strict-equality failure is NOT repaired, weakened or rerun: test_acceptance.py and
all original remainingAcceptance strings are byte/value identical to this base.
Prior 3.31–3.45 runtime tests are neither edited nor rerun as new qualification.

## Honest remaining scope
This service expects trusted App ports; it does not establish real operator
identity, authenticated publisher onboarding, a trustworthy physical clock,
a file-picker UI, project/entity availability, template/blob execution, supported
renderers, runSkill expansion or a deployed App integration. Those gates are not
proved by a valid signature or by an in-memory acknowledgment.

No shelf writes/install, cross-namespace transfer, production FTS/RAG, paid API,
real model/provider/device, iOS/Mac/XS or production acceptance is claimed. No
schema v10, durable mailbox, renderer, job or other deferred runtime is invented.
Project user_version remains 9 and InversePatch remains restoreSnapshot.
Counts remain 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0; T-4 and the overall program remain unfinished.

## Next increment
Complete concrete Web-verifier/adapter and trusted App-composition bindings under
t155u, then qualify that port separately with published/hostile-input tests.
Do not extrapolate native results into Web acceptance, durable installation,
production key provisioning or provider/device qualification.
