# ADR 0006 — Linux OS identities, explicit session UI and bounded peer inbox

Status: implemented Linux development slice; not whole-task or cross-platform qualification.
Date: 2026-11-25, Asia/Shanghai. Requirements: t82u/t83u/t84u and original PlanGraph/lease/fence contracts.
Original104 exports remain immutable. Supplements ADR0005; no change to its authentication or SQLite gate.

## Decision and real operator path

The shared native Flutter FoundationApp now has a collapsed **Trusted peer session · Linux preview** panel
(`studio_peer_ui`). Nothing listens or generates an identity at startup. The operator explicitly
loads/creates an identity, compares the **entire** other device's certificate SHA256 using an
independent trusted channel, consents to metadata and, separately, an exact prepared blob.
Copy/paste offers and invitations contain public certificates, pins and connection/scope data,
never private keys. No discovery service, cloud material upload, relay or paid fallback exists.

Initial identity generation/loading is qualified on **Linux only**. It uses the mature
`flutter_secure_storage` 11.2.0 Linux plugin 3.0.3 / libsecret Secret Service, plus official
OpenSSL EC P-256 certificate generation. Private PEM is passed to OpenSSL on stdin and held
in native process memory and the OS store, not command arguments, a project/database/archive,
plaintext PEM files or logs. ACK follows exact OS-store readback. The Linux plugin read-modify-writes an APPLICATION_ID-wide aggregate item: all identities therefore
use one process FIFO and the SDK's stable **OS-user-root/store-wide** cryptographic lock filename,
not separate namespace locks. A blocking file lock serializes cross-process store mutation.
Direct library callers must use the same SDK-provided lock path for all namespace identities.
A storage/readback/certificate error does not create a replacement identity or plaintext fallback.
This is **encrypted-at-rest**, not hardware-backed/nonextractable signing or guaranteed memory erasure.
No whole-store enumeration, clear or existing-owner keyring access is needed by acceptance tests.

The certificate binds one explicitly selected IP SAN for 365 days. Default is loopback. Selecting
LAN before first creation additionally requires the explicit LAN-enable checkbox before listening.
Address/key rotation and expiry-renewal UI are not implemented; an address change fails closed.
Non-Linux provisioning rejects with IDENTITY_PLATFORM_NOT_QUALIFIED. LAN reachability, firewalls,
NAT traversal and actual physical devices remain unqualified. Do not promise arbitrary Internet direct access.

One UI session authorizes **one peer**, one selected node and a ten-minute grant. Its real project
revision is frozen into the original Harness PlanGraph. Two bounded free `core.digest-json` nodes
operate on explicitly consented project metadata/captions (combined input <=64KiB): one executes
on the authenticated worker, the other locally in **the same session/PlanGraph**. Outputs are pinned,
source-checked candidates/outbox receipts; they cannot mutate Project revision. This is a real
bounded CPU path, not arbitrary model/FFmpeg execution or a general N-device UI. Runtime pins
are local-host-qualified, not signed remote hardware/model attestations. The local executor uses
one stable logical device slot per namespace/database across UI sessions, not a fresh per-session
identity that could bypass resource admission. A real overlapping-session test rejects the second
claim with DEVICE_RESOURCE_BUSY, then succeeds after the first commits. This remains namespace-local,
not global physical-host arbitration across applications/databases.

Revocation closes the endpoint and fences the old grant. Re-pairing explicitly creates a fresh
session instead of reviving old authority. Server close during bind closes the eventual socket;
listener cleanup runs even if revocation throws. Host application restart does **not** silently
restore permission/listening. Core local-owner boot takeover/quarantine is still separate from
an unimplemented interactive coordinator-recovery workflow. If a process dies while a local slot
is running, another coordinator cannot simply replace its device ID or erase the reservation;
explicit trusted-local recovery is required. No new UI automatically restores old permissions.

## SQLite v6 bounded inbox, not project CAS

Additive checksum migration v6 creates `peer_blob_stages`, `peer_blob_chunks`, `peer_blob_objects`.
It leaves v1-v5 DDL/checksums untouched and preserves default exact approved SQLite3.54.1
SOURCE_ID + THREADSAFE=1. System3.46.1 remains rejected; no renamed version assertion is used.

Each local grant defaults to **no blobs** and may whitelist at most two exact raw SHA256/size
pairs. Limits: 16MiB/blob, 64KiB exact chunks, 64MiB total logical reserved stage payload per
namespace. Existing authenticated dispatch additionally caps unique request receipts at10000/grant. Retained chunks and committed objects duplicate bytes: this is **not** a hard64MiB
physical disk cap; payload storage can approach128MiB plus database/WAL/index/receipt overhead.
There is no inbox GC/reclamation UI yet; quota exhaustion is an explicit refusal, not auto-deletion.
No peer-provided path/name or decoder is accepted; downloaded data stays in a bounded owner inbox,
not automatically in Project CAS, a model input, export archive or the local media library.
Revocation prevents further network access but cannot retract bytes already explicitly delivered.

`blob.begin/status/chunk/finish` use the existing authenticated request dispatch: certificate,
namespace/session/plan/revision/node, expiry and current grant epoch are checked **before cached
receipts**. Persistent chunk indices survive receiver DB/listener reopen. Chunk hash/length,
conflicting repeats and final full hash are checked. Equal bytes in valid alternate Base64 encoding
remain idempotent. Status/chunk responses query indices only, not all prior payload bytes on every
request. Final assembly alone loads the bounded chunks. Object + committed stage + one ready outbox
+ request receipt share the same transaction; a real trigger abort proves rollback and retry.

The UI explicitly prepares a local file using bounded openRead (max16MiB+1) and freezes an immutable
typed snapshot before its hash/size can be approved. The path is never sent. Sending with the same
identity/grant resumes only missing durable chunks. Full host UI restoration, full media-CAS adoption,
large-file streaming/GC and user-visible interruption management are still missing.

## Web boundary and deviations

The Web editor remains functional for metadata/captions with actual IndexedDB CAS, not a read-only
showcase. It cannot import native `dart:io`/FFI/OS-keyring UI. Native mTLS is **not** a browser
transport: no certificate-bypass callback, anonymous websocket, ambient-cookie identity or
unverified self-signed HTTPS fallback was added. Authenticated browser-native transport is still
unimplemented; WebRTC with independently authenticated signaling would require actual identity,
permission/replay/resume integration and browser network evidence before qualification. No silent
cloud signaling, paid TURN or arbitrary model sharding is implied.

## Actual acceptance and reproducibility

See `docs/implementation/evidence/peer-ui-blob/` and README commands. Acceptance creates a fresh,
isolated D-Bus session/HOME/XDG keyring and uses the actual libsecret plugin, real native Flutter
UI, TLS sockets and SQLite — no platform-channel, storage or transport mocks. Two panes execute
pair -> remote CPU -> separately consented file transfer -> local CPU same session -> revoke ->
fresh re-pair. Test-only keyring password is randomly generated in memory and piped to its daemon;
it is never a user credential or saved in evidence. Existing owner keyrings are not read/unlocked.
The runner confirms a real encrypted keyring file and absence of plaintext private PEM files.
This proves same-host native UI/protocol integration, **not two physical devices**.

Separate real TLS tests disconnect/reopen/resume, verify exact bytes/single outbox/no revision
mutation and reject missing blob consent, early finish, bad hash, changed duplicates and revoked
receipt replay. Real committed v4/system3.46.1 -> v6/fixed3.54.1 and v5/fixed3.54.1 -> v6 migrations
preserve content/integrity and their respective known lease deadlines (500ms vs1000ms). An initial
probe incorrectly expected500ms for v5; corrected only the baseline-specific harness expectation,
not production schema, gate or migration behavior. Historical failed evidence is retained.

Not verified: locked/denied OS-store interaction, other desktop/mobile key stores or app builds,
physical devices/LAN, encrypted Web transport, mobile/browser background behavior, full project
CAS sync/adoption/GC, joint edit proposal UI, full original Schema/RenderGraph, real audio/AAC,
models/paid work/global resource telemetry/privacy-rights epochs. Original87 and newXD10 remain
independent with unchanged full acceptance criteria; this bounded passing path does not mark
these entire tasks complete.

## Dependency documentation checked this increment

- https://pub.dev/packages/flutter_secure_storage (Linux runtime/build libsecret and keyring prerequisites)
- https://pub.dev/packages/flutter_secure_storage/changelog (11.2.0 and fail-closed Linux fixes)
- https://pub.dev/documentation/flutter_secure_storage_linux/latest/ (actual Linux provider boundary)

Official package documentation was checked2026-11-25 (Asia/Shanghai); upstream claims are not
substitutes for the actual isolated libsecret/UI tests or qualification on unsupported platforms.
