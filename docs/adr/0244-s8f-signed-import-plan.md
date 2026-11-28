# ADR 0244 — Complete the exposed signed Film/Craft import plan

## Status and sources
Accepted plan supplement for Increment 3.45 under t155u, preserved base
0f3f32d33d5412d08825f7a0ed7eea09e54b1838. Not a cryptographic implementation.

s8f:7,73–80 required importPack(token,namespace,signaturePolicy), integrity,
trust chain, license facts, permission diff and confirmation, but left the
wire format, signed bytes, provisioning and signaturePolicy unspecified.
s10:38 also requires existing SkillPackage manifest/schema/fixture fields.
ExternalSkillRequest.signed is only a privilege-model input (skill_privilege.dart
71–73); ADR 0140 did not implement a package loader or cryptographic verification.

## Decision
Adopt [the official v1 supplement](../studio/spec/s8f-signed-import-v1.md).
It specifies DSSE 1.0.2 PAE over exact immutable payload bytes, Pure Ed25519,
a bounded detached single-skill JSON bundle preserving manifest fields, and a
threshold of distinct publisher keys pinned in trusted build-time AppProfile.
The default key set is empty. Pack-supplied keys/keyids never create trust.
The direct configuration-to-key edge is the only supported trust chain;
remote discovery, delegation and automatic rollover are refused/unsupported.

Hash/namespace/Version use the existing s8g types. signatureRef is null in this
profile, avoiding circular self-hashes. Both DSSE base64 alphabets are accepted;
unknown envelope fields are ignored per the published DSSE envelope, while
payload/manifest objects remain closed. No JSON reserialization precedes
verification. The same decoded bytes reach schema and privilege assessment.

Signature threshold, namespace, epoch, revocation, time and schema are integrity
gates, never license warnings. Existing s1a/s1c license facts/risk warnings remain
unchanged. Invalid signed content cannot downgrade into unsigned preview.
Unsigned knowledge preview and all existing tool/grant/approval bounds remain.
Verification reports are importer-owned, not old signed/userConfirmed booleans.
Preview acknowledgment is not installation or tool approval; no shelf persistence,
project schema migration, new operator or runtime grant is added.

## Why plan-only in this increment
The t155u prerequisite is security-sensitive and spans parsing, cryptographic
backend admission, fixture closure and preview identity. Land its complete
protocol/profile contract with preservation and reference-encoding checks first.
A locked maintained verifier backend and full adversarial import interface suite
are the next coherent implementation slice, not hurried into this plan commit.
No cryptographic verification, root provisioning, installation or product acceptance
is claimed by this document. There was no contradictory official contract to
invent around; the chosen v1 restrictions are explicit unsupported cases.

## Evidence and status
`tools/tests/test_signed_import_plan.py` checks plan structure, source contracts,
unchanged acceptance labels/task counts, append-only original s8f text and DSSE
reference PAE encoding. This does NOT run Ed25519 or qualify a loader.
New plan suite: 7 passed. Broader tools.tests.test_acceptance: 5 passed,
1 PRE-EXISTING failure: strict equality with original acceptance labels conflicts
with historical append-only notes (first at V-002; already present at base).
The failure and 59 baseline mismatches are recorded separately; the old test
and all old acceptance text were not weakened or rewritten. Python py_compile
and git diff --check pass. No Dart/runtime qualification is run in this plan-only
increment. Evidence: `docs/implementation/evidence/signed-import-plan-v1/`.
I-037 remains partial. Counts stay 0 complete / 62 partial / 12 planned / 13 blocked;
fullTasksCompleted=0 and T-4 / the program remain unfinished. No original
remainingAcceptance or remainingScope wording is rewritten. Project user_version
stays 9 and InversePatch stays restoreSnapshot. All executable files, frozen
assertions, prior qualification and source schemas are unchanged.

## Next
Implement only this bounded local import-to-preview and acknowledgment validation
with RFC 8032/backend-negative and hostile parser/trust/scope tests. Do not repeat
format-repair qualification. Durable library installation, cross-namespace import,
production FTS/RAG, hardware/provider/model acceptance, paid APIs and all deferred
runtimes remain outside this result.
