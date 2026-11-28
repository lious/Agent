# 8F supplement — signed Film/Craft import verification v1

Status: official plan supplement, Increment 3.45, under t155u. This document
specifies the previously missing envelope, authenticated bytes, local trust and
signaturePolicy for s8f:7,73–80. It is NOT an implemented verifier or security
audit. ADR 0244 records the boundary. The initial implementation slice is a
bounded local import-to-preview, not installation, network retrieval or FTS.

## S1 — standards and crypto boundary

Use DSSE protocol 1.0.2 (2024-05-10) with its JSON envelope and Pure Ed25519
(RFC 8032 sections 5.1 and 7.1), NOT Ed25519ph, custom MAC, RSA fallback or
signature booleans. Sources read 2026-11-28 (Asia/Shanghai):
- https://raw.githubusercontent.com/secure-systems-lab/dsse/master/protocol.md
- https://raw.githubusercontent.com/secure-systems-lab/dsse/master/envelope.md
- https://www.rfc-editor.org/rfc/rfc8032.txt

The production implementation must use a maintained Ed25519 verifier dependency
with exact version/hash locked and its applicable license recorded; never write
curve/signature arithmetic here. Before admitting its backend, run RFC 8032
positive vectors and negative canonical-encoding/S>=L/small-order tests.
Public keys must be canonical 32-byte Ed25519 keys, signatures 64 bytes; reject
invalid point encodings, small-order keys/R points and noncanonical S. A backend
that cannot demonstrate these refusal semantics remains unavailable. This plan
does not select or qualify native hardware or a cloud verification service.

## S2 — bounded single-skill envelope and exact authenticated bytes

Input token means an App-supplied local, user-selected read capability, NOT a
path or URL from a model. Capture its bytes once into a bounded immutable buffer.
No URL fetching, symlink following, ZIP extraction or executable loading.

The container is a UTF-8 DSSE JSON envelope, max 4 MiB encoded. Require
payloadType, payload, signatures; signature entries require sig and may carry
keyid. Per DSSE envelope 1.0.2, ignore unrecognized ENVELOPE/signature-entry
fields within the same resource limits; never forward them as manifest fields
or let them select algorithms/policies. keyid absent equals empty. signatures is an array of 0..8 entries. payloadType is
exactly `application/vnd.studio.filmcraft.import.v1+json`. Reject duplicates at
EVERY JSON object level, invalid UTF-8/Unicode scalar strings, BOM, trailing JSON,
NaN/Infinity; a normal map decoder that loses duplicate keys
is insufficient. Maximum JSON nesting depth 32; reject before unbounded parse.
Both ordinary and URL-safe RFC 4648 base64 alphabets must be accepted as DSSE
requires. Accept their standard padded or unpadded form, reject whitespace,
mixed alphabets, invalid lengths and nonzero unused pad bits. Decode each field
once; never verify one parse and consume a second parse of the envelope.

Authenticated bytes are exactly:

    PAE(type, body) = ASCII("DSSEv1") || SP || ASCII(decimal(byteLength(type)))
      || SP || UTF8(type) || SP || ASCII(decimal(byteLength(body))) || SP || body

Decimal lengths have no leading zeros; SP is byte 0x20. body is the decoded
payload bytes, unchanged. Sign/verify the COMPLETE PAE bytes with Ed25519,
not SHA256(body), not reserialized JSON and not a signature over a filename.
There is deliberately NO JSON canonicalization step: alternate whitespace/key
order makes different signed bytes and requires its own valid signature. After
verification, parse exactly that same immutable body. Never normalize Unicode,
sort keys, trim strings or discard unknown fields to make a signature pass.

Payload is strict UTF-8 JSON, decoded max 2 MiB, with exactly these fields (all hashes below use s8g Hash = `sha256:` + 64 lowercase hex):
- schemaVersion: literal `1.0.0`; contentType: literal `filmCraft`;
- skillId: s8g Id; version: s8g Version (three numeric components);
- manifestHash: Hash of the exact decoded `skill-manifest.json` bytes;
- entrypoint: literal `film-skill.json`;
- files: array of EXACTLY three closed objects with path, mediaType, byteLength,
  sha256, data, one each for `film-skill.json`, `skill-manifest.json` and
  `test-fixtures.json`. mediaType is `application/json`, byteLength is integer
  1..1048576 per file, sha256 is Hash, data is base64;
- licenseEvidence: array of 0..16 closed objects {licenseId, termsSha256} using
  s8g Id and Hash. These are provenance claims, not grants.

Decode file data once; verify exact byteLength and SHA256 before schema parsing.
Only those three exact ASCII file paths are supported in v1: reject absolute/drive/UNC paths, slash or
backslash traversal, empty segments, dot segments, NUL, percent-encoded path
aliases, duplicate names and case aliases. Do not normalize a hostile path into
an accepted path. Files are never extracted to a user-chosen directory.

The entrypoint must validate against the CLOSED `urn:studio:FilmSkill:1.0.0`
schema in s8g (the block beginning at line 5514 at the preserved base), using
its bundled local definitions only; do not weaken its required fields
or allow remote $ref. Its own id/version must equal payload skillId/version.
The entrypoint namespace is the s8g object {appId,tenantId,workspaceId}; all
three fields must equal the target namespace without rewriting signed content.
This initial profile rejects cross-namespace transfer rather than creating a
ShareGrant. signatureRef must be null in this detached-envelope profile: a
self-reference to a signature over itself cannot be resolved; non-null legacy
signature references are unsupported, not silently trusted or erased.

Preserve s8f:19–20 and s10:38 SkillPackage fields: `skill-manifest.json` is a
closed object {version,contentType,requiredTools,inputSchema,outputSchema,
testFixtures,payloadPath}. version/contentType/requiredTools exactly match the
payload/entrypoint; payloadPath=`film-skill.json`; testFixtures is the closed
reference {path:`test-fixtures.json`,sha256:Hash}. Its hash must equal the actual
file hash and the entrypoint testFixturesHash. manifestHash is deliberately
outside the manifest, not a recursive self-hash. `test-fixtures.json` is a closed
object {cases:[{input,expectedOutput}]} with 0..16 closed cases. Their values are
JSON, not scripts, and are schema-checked but NEVER automatically executed.

inputSchema/outputSchema are a bounded local declarative subset of JSON Schema
2020-12: boolean schemas or objects using only type,properties,required,
additionalProperties,items,enum,const,minimum,maximum,minItems,maxItems,minLength,
maxLength,$defs,$ref. Validate keyword value types against the bundled metaschema;
$ref is only an existing local #/$defs/name (no recursion, aliases, URL resolution
or nested external schemas); refuse other keywords, not silently ignore them.
Schema definition names match `[A-Za-z][A-Za-z0-9_]{0,63}`; no URI/JSON Pointer
unescaping is needed for this restricted reference syntax. type is one of the
standard seven JSON Schema type strings (not a coercion rule); numeric values
must be finite. Object schemas explicitly set additionalProperties=false and
required is a unique subset of properties. Bounds are nonnegative safe integers
for lengths/counts; min <= max. Refuse invalid/unknown keyword combinations
rather than treating a malformed schema as a boolean true schema. Schemas and
fixture values share the byte/depth bounds. Each input and
expectedOutput must satisfy its respective schema. This transport subset does
not weaken the richer App-bundled s8g FilmSkill schema or add a new plugin type.

Preserve original payloadHash=SHA256(body), file hash and envelopeHash=SHA256(the
exact selected envelope bytes) separately. No archive/runtime/schema migrator is
introduced. Multi-skill/resource archives are unsupported, not silently flattened.

## S3 — trusted signaturePolicy and provisioning

Policy comes ONLY from installed trusted AppProfile configuration, never from
the pack, model, SkillPackage or an import dialog's self-asserted signed flag.
The local policy record has exactly:
policyVersion=`filmcraft-import-v1`, policyEpoch (integer 1..9007199254740991), appId,
namespace (exact target s8g Namespace object), threshold (integer 1..8), trustedSigners (0..8),
maxEnvelopeBytes=4194304, maxPayloadBytes=2097152, maxFileBytes=1048576.
If trustedSigners is empty, verified import is unavailable even if signatures
are mathematically valid. Namespace argument MUST equal policy namespace and
the requesting App scope, and namespace.appId must equal policy/appProfile.appId. A pack cannot choose another policy.

Each trusted signer is a distinct public-key record:
{publicKeyBase64, keyFingerprint, role, notBefore, notAfter, revoked}.
role must be `filmCraftPublisher`; times are integer Unix seconds in 0..9007199254740991 with
notBefore < notAfter; revoked is a trusted boolean; keyFingerprint is `sha256:` plus lowercase SHA256 hex of
the exact raw 32-byte public key. Reject duplicate keys/fingerprints or invalid
policy configurations; threshold cannot exceed the number of distinct configured
keys, EXCEPT the explicitly disabled empty-set default: that is a valid policy
with verified import unavailable (threshold remains 1). It does not disable the
separate unsignedUntrusted knowledge-preview path. Threshold keys must all be
currently permitted for THIS app/namespace.

Provision keys out of band ONLY as build-time AppProfile configuration delivered
with the trusted App binary. The operator reviews publisher public-key fingerprints
through its independent release process; key changes require an explicit App
release/update. No runtime key-enrollment UI or update protocol is invented. No pack-supplied public keys, self-signed certificate, OS/global CA,
email/domain reputation, model response, first-use trust or network key lookup
can populate this table. Default shipped trusted signer set is empty until the
App operator deliberately provisions actual publisher public keys. No user's
private signing key or credential is requested or stored in a project.

The v1 trust chain is deliberately ONE direct edge: trusted local configuration
-> explicitly pinned publisher key. Delegation, pack-provided certificate chains,
remote key discovery and automatic rollover are unsupported, not accepted on
an unverified chain. This is a restricted trust-chain policy, not a replacement
PKI or a claim of publisher identity from cryptography alone.

keyid in DSSE is an UNAUTHENTICATED routing hint. Never count it as a verified
identity. For each signature, try the bounded configured eligible keys (hint may
reorder attempts but cannot authorize a key or omit required threshold checks).
Count distinct successfully verifying PUBLIC KEY BYTES, not signature count,
keyid strings, or aliases. Duplicate signatures cannot satisfy a threshold.
Malformed signature entries reject the envelope; otherwise invalid/untrusted
signatures contribute zero and a threshold is required. Unknown algorithms
cannot be negotiated by the envelope. Signature invalidity is never a license
warning and cannot fall back to unsigned or a more permissive policy.

Trusted current time is supplied by the App, not the pack. If clock confidence
is unknown or a trusted clock rollback is detected, return needsReview and no
verified preview. Eligibility uses notBefore <= now < notAfter and !revoked.
Snapshot policyEpoch and time at verification, recheck both when acknowledging
preview; changes/expiry/revocation invalidate that preview and require fresh
verification. Local revocation applies immediately to FUTURE import/acknowledge;
this does not promise knowledge of offline remote revocations or cancel jobs,
delete originals, rewrite pins or requalify already accepted project content.

## S4 — verified preview is not execution authority

importPack(token, namespace, signaturePolicy) returns an immutable app-owned
preview/report after bounded decode, threshold verification, manifest/file/schema,
existing privilege checks and license-fact assessment. Caller cannot construct a
verified report by passing ExternalSkillRequest.signed=true. Keep that existing
field and all ADR 0140 privilege tests unchanged: they model privileges only.

The report contains previewId (fresh App-generated opaque nonce, at least 128
random bits from the platform cryptographic random source), envelopeHash,
payloadHash, contentHash (entrypoint hash), namespace, policyEpoch, verified key
fingerprints, trustState, requiredTools, permissionDiff and licenseFacts. The App
retains the exact immutable decoded content behind previewId; the UI/LLM supplies
only that ID back, never substituted bytes, claims, signatures or booleans.

trustState is `verified`, `unsignedUntrusted` or `needsReview`. A signed envelope
must satisfy threshold or return an error (not unsignedUntrusted). An actually
unsigned signatures=[] pack may enter ONLY the existing untrusted KNOWLEDGE
preview path after the same structural/hash/schema/safety checks. It cannot be
installed as verified, grant tools, bypass gates, or be silently upgraded by a
confirmation click. No "strip invalid signature" fallback exists.

permissionDiff is the sorted, duplicate-free missing requiredTools list relative
to the allowed-tools intersection, plus the sorted requiredTools list; retain
its exact App-produced UTF-8 JSON bytes and SHA256 digest (no reserialization on
acknowledgment). No cross-system canonicalization is needed for this local opaque
preview binding. permissionDiff reports declared requiredTools relative to installedAllowlist
intersection sessionGrant intersection branchScope; it grants nothing. Reuse
existing ADR 0140 checks for forbidden code/shell/network/model/shader steps,
DAG<=16/cycle refusal and confirmation; do not count those as new qualification.
A signature does not make an unsupported renderer executable.

The user acknowledgment binds previewId+payloadHash+contentHash+namespace+
policyEpoch+permissionDiff digest. Recheck immutable content, policy/time and
scope before acknowledging. Missing/expired/stale acknowledgment yields no
install or execution authority. v1 import implementation stops at this bound
preview/report and acknowledgment check; no shelf persistence schema or installer
is added. Later durable installation is a separate planned slice. Every actual
compile/execution still needs existing current grants/approvals and its own
normal gates. Do not turn this acknowledgment into ApprovalReceipt for tool use.

LicenseEvidence is assessed as facts/warnings under s1a/s1c, never proof of a
license grant or a reason to erase selected bytes. Missing/unknown/restricted
license facts retain existing warning behavior; do not introduce a license hard
block, new license policy, license-grant writeback, or font/model collection.
The existing project commercial-component allow_with_warning rule stays intact;
privacy/portrait/source-consent and other independent gates remain separate.
By contrast invalid bytes/hash/schema/signature/trust fail verification for
integrity/security reasons. Nothing here requalifies I-033/I-058 license bounds.

## S5 — implementation checklist, errors and adversarial tests

Use stable local outcome codes for importer diagnostics:
SKILL_IMPORT_LIMIT, SKILL_IMPORT_ENCODING, SKILL_IMPORT_SCHEMA,
SKILL_IMPORT_PATH, SKILL_IMPORT_HASH, SKILL_IMPORT_POLICY,
SKILL_IMPORT_SIGNATURE, SKILL_IMPORT_SCOPE, SKILL_IMPORT_PREVIEW_STALE.
needsReview is a report state (clock confidence), never verified success.
Keep existing privilege-code meanings unchanged. Any failure creates no verified
report, no files on disk, no document writes, no network and no authority.

Before implementation is accepted, test separately:
1. DSSE PAE published vector and UTF-8 byte lengths; RFC 8032 Ed25519 verification
   and canonical/small-order negatives through the selected LOCKED backend.
2. Tampered payload/type/signature; wrong type; hash mismatch; unsigned vs invalid
   signed; attacker-supplied keyid; duplicate signer aliases/threshold; no roots.
3. Policy namespace/app/role mismatch, revoked/expired/not-yet-valid keys,
   unknown/rollback clock and changed epoch/time before acknowledgment.
4. Duplicate JSON keys at all layers, malformed base64 including nonzero pad bits,
   both supported alphabets, changed envelope parse and attempted payload swap.
5. File path aliases, traversal, byte limits, depth limits, unknown payload/manifest fields (envelope extras ignored),
   mismatched skill id/version, invalid local schema and remote-reference refusal.
6. Preview acknowledgment cannot grant tools, change scope, install content or
   become tool approval; no fallback from invalid signature; no network calls.

These are PLANNED tests. Increment 3.45 has documentation/reference-encoding
checks only, not an implemented verifier. Implementation follows as a separate
increment after this security-sensitive plan prerequisite. No production FTS,
paid API, real model, new privilege path or private-key handling is authorized.

## S6 — existing-contract crosswalk (preserved base 0f3f32d)

- [s8f](s8f.md):3,7,19–21,73–84: existing SkillPackage content type,
  import-to-preview, path/size/hash/schema/trust/license, unsigned preview,
  privilege intersection, per-step gates and immutable project skill pins.
- [s10](s10.md):38: retain manifestHash/version/requiredTools/inputSchema/
  outputSchema/testFixtures; installation signature OR user confirmation does
  not enlarge privileges. This profile only covers the signed preview branch;
  untrusted unsigned preview remains possible, with no claim of installation.
- [s8g](s8g.md):5514–5614 and its FilmSkill definition: use Namespace object,
  prefixed Hash and Version pattern; 7355: receiving App revalidates, no revival
  of source-App approval. The restricted same-namespace profile never rewrites
  the signed namespace to fake cross-App acceptance.
- [s1a](s1a.md):10, [s1c](s1c.md): existing App isolation and license warnings.
- [ADR 0140](../../adr/0140-i037-external-skill-privilege.md): existing
  privilege-only qualification is preserved. Its historical "do not start"
  signed import boundary remains true for that increment; t155u now permits
  completing this previously exposed plan, not claiming its implementation.
- `packages/studio_assets/lib/craft/skill_privilege.dart`:71–73,110–125:
  ExternalSkillRequest is not a loader; the existing public SkillImportPreview
  remains the privilege-only view. Add a separate importer-owned verification
  report wrapping that view rather than retroactively certifying its booleans.

Project user_version stays 9; InversePatch kind stays restoreSnapshot. No schema
v10, library migration, restore service, ZipPlanner, durable mailbox, new DAG
runtime, production FTS/RAG or paid service is opened.

### Increment 3.46 implementation-exposed resource bindings (t155u)

Before implementing adversarial schema traversal, close the computational bound:
byte/depth limits alone do not bound repeated acyclic local-reference expansion.
Each schema-validation operation and each manifest-metaschema operation has a
200000-visit/comparison budget; exhaustion is SKILL_IMPORT_LIMIT, not a license
warning or permissive success. Local-reference aliases (a definition whose body
contains $ref) are unsupported; cycles remain refused. At most 16 immutable
pending previews are retained per importer; discard/one-shot acknowledgment
releases the captured bytes. No disk storage or durable queue is introduced.

Acknowledgment needs a trusted App UI user-action capability, not merely an ID
echoed by a model. The App mints a local one-use gesture handle for that retained
preview after explicit UI consent; the importer accepts that opaque handle, not
userConfirmed/signed booleans. The resulting record still grants no installation
or tool-execution authority. This completes an implementation-exposed binding,
not a new tool-approval API.

The selected native verifier also enforces canonical prime-subgroup public keys
and R points through libsodium's maintained point-validation API. No App curve
arithmetic or custom point blacklist is added. This increment's executable port
is explicitly Linux-only; shared/Web entrypoints do not import dart:ffi. An App
release must independently pin its immutable deployed binary hash. The recorded
DEV host artifact and test publisher keys are not production trust provisioning.

A further parser binding exposed during implementation: finite JSON numbers must
round-trip through the selected host number decoder without changing their
normalized decimal value. Unsupported precision/underflow is refused as
SKILL_IMPORT_ENCODING/numberPrecision rather than silently making distinct
const/enum fixture values equal. Decimal equality/order use normalized decimal
components, not reserialized signed bytes. This is a range/precision limit
permitted by RFC 8259 section 6 (https://www.rfc-editor.org/rfc/rfc8259.txt), not
an arbitrary-precision JSON engine or a Web-number compatibility qualification.
Original authenticated bytes are NEVER rewritten; Time integer strings remain
unchanged. Out-of-range non-byte integers cannot enter a captured byte token.
