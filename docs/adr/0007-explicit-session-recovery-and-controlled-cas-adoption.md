# ADR 0007 — Explicit session recovery and controlled CAS adoption (v1.3)

Status: implemented Linux development slice; original full contracts unchanged.
Date: 2026-11-25 (Asia/Shanghai). Effective requirements: t82/t83/t84.

## Decision / architecture

Reuse the original Harness PlanGraph, SQLite transaction/outbox, boot CAS, lease,
fence, attempt ceiling and wall budget. Do not create a second scheduler. SQLite
migration v7 adds owner-bound metadata recovery manifests and project adoption
idempotency receipts; prior DDL/checksums are unchanged. A manifest freezes bounded
(64KiB) metadata inputs, exact plan hash, owner certificate fingerprint and a local
clock anchor. It is not an exported credential, remote RPC or transfer of project
write authority. Corrupt/checksum-invalid manifests fail closed.

Linux64 uses libc `clock_gettime(CLOCK_BOOTTIME)` and the kernel's boot_id, not
peer/user wall time: suspend time counts, and same-kernel-boot process restarts can
account for unobserved time. Only an anchor matching both current coordinator boot
and kernel boot can be used. Unknown/reboot/unsupported-platform downtime consumes
remaining wall budget rather than creating a free budget. Actual process/repository
reopen is tested; OS suspend/reboot and non-Linux clocks are NOT qualified.

The operator reloads the same OS identity, explicitly lists/selects a recoverable
session and consents to recovery. In one transaction: expected-boot CAS, original
budget/attempt/fence takeover, revoke all old grants, retire old pairing offers,
record new boot/anchor/idempotent receipt. Fresh coordinator construction always
generates a new UUID boot independent from session ID; re-registering an existing
plan with a different boot is fenced, never a hidden recovery/budget reset. A real
regression first reproduced the old constructor returning a live coordinator for
the same session ID, then verifies rejection after this fix.
Stale SDK objects also cannot issue/revoke grants, publish invitations, register
recovery or start listeners after takeover. Grant creation/confirmation and revoke
share a boot-checked writer transaction. Closing an old coordinator still closes
its listener but must not revoke a newly approved current-owner grant. All peer
RPCs (including blobs and cached responses) already check current coordinator boot
before dispatch. A separate real regression proves stale administration denial
and preservation of the new grant after old-object close.
Replaying that exact recovery operation
must not revoke newly approved grants again. No listener, peer, metadata/blob
consent or permission is automatically restored. An old still-listening endpoint
cannot replay an old response after recovery. Project-revision drift rejects
recovery. Other trusted-local core callers may invalidate a stored anchor; that
causes unknown downtime, not a guessed clock conversion.

## Resource correction discovered by real regression

The previous claim path looked for quarantine only in its own coordinator boot;
a fresh session could ignore another boot's recovered-device reservation. A real
concurrent CPU regression first produced an unexpected successful result (retained
failure log). Claims now consider all namespace/device quarantine rows. Foreign
clock expiry requires an observation from that boot's persisted plan clock, never
comparing unrelated monotonic epochs. Takeover carries all old quarantine rows
conservatively into the new clock and retires the old copies. This is conservative
namespace/database-local accounting, NOT global physical-host resource attestation.
It can block until that owner explicitly recovers/observes expiry.

## Received bytes -> project -> saved/reopened/exported video

The owner explicitly pastes a received raw hash and adopts it using a fresh local
intent ID. Recheck inbox hash; publish into production immutable namespace CAS;
probe with actual C++ FFmpeg; apply the existing video admission gates (including
explicit video-only consent for audio-bearing inputs); atomically commit the
original AppendVideoAsset edit and persistent adoption receipt. An exact retry
returns current head without appending; changed parameters/expected revision with
the same intent fail. Unknown license remains allow_with_warning, NOT fabricated
rights, device consent or privacy approval. No remote path, automatic adoption,
model execution or material upload is added.

All supported SDK CAS publishers (local import, peer adoption, archive restore)
and explicit GC share one stable namespace filesystem lock plus owning-isolate FIFO.
Publication holds that lease through SQLite pin commit. GC holds a SQLite writer
transaction while reading ALL historical blob_edges, preserving undo/checkpoints/
archives' retained history, and removes only unreferenced canonical regular files
(max1000 per invocation). Symlinks are refused; staging/unknown names ignored.
Queued imports/adoptions also pin project AND writer identity across awaits, so a
same-project close/reopen writer ABA cannot silently change the target/fence.

Inbox GC is a separate real SQLite transaction: only revoked/expired/old-epoch or
missing-grant stages, their chunks, then unreferenced inbox objects. Active grants
remain pinned. DELETE-trigger failure proves SQL rollback. Physical SQLite file
size/WAL shrink is NOT promised. 64MiB remains a logical stage reservation, not a
physical disk ceiling. Filesystem GC is not globally rollbackable: interruption
may leave additional orphan files; it never intentionally removes a pinned file.
No history pruning, automatic GC, VACUUM, or deletion of user-selected originals.

Dart POSIX file locks are process-level advisory locks, not cross-isolate mutexes.
Supported apps own repository/CAS publication in one main isolate; media probe
isolates do not publish or GC. Multiple independent publisher isolates in a single
process are NOT qualified/supported; they need one owner-isolate broker (or a
separate proven process-global lock) before enabling concurrent publication/GC.
Raw BlobStore callers must follow the documented lease/transaction preconditions;
this is not a sandbox against trusted local code directly editing managed files.

## Web transport decision / remaining work, not an invented external blocker

Native mTLS is not a browser transport. Official WebRTC/MDN documentation supports
persisting RTCCertificate handles in IndexedDB, checking expiry, reusing a cert in
RTCPeerConnection and independently confirming full SHA256 fingerprints before
accepting remote SDP; DTLS does NOT itself authenticate a human. A manual-SDP,
no-STUN/no-TURN datachannel path could avoid cloud signaling/relay, with explicitly
unreachable ICE/NAT cases. This is a viable next implementation, NOT a claim that
Web is impossible and NOT a qualification result.

Still missing: real WebRTC adapter + native interop, persisted browser identity/
scoped grant/revocation lifecycle, original scheduler RPC/receipts integration,
and authenticated browser/native end-to-end tests. No anonymous socket, certificate
bypass, plaintext private-key fallback, custom encryption or automatic cloud/paid
relay was substituted. Existing actual Chrome editor/shared-core tests do NOT test
peer transport. Web networking remains unimplemented, not externally blocked.

## Evidence / boundaries

See docs/implementation/evidence/recovery-adoption and REVIEW.md. Real mTLS upload
-> owner CAS adoption -> save archive -> reopen -> 90-frame native silent H264 export
is exercised, plus trigger abort/retry, dedup, overlapping GC, historical pin/undo,
identity/revision/old boot boundaries and actual OS-keyring/native recovery UI.
No physical-device, LAN/NAT, browser peer, mobile, macOS/Windows, hardware/model/
audio/AAC/export-render qualification is inferred from Linux same-box integration.
Original87/newXD10 retain their complete original acceptance and separate statuses.

Sources opened this increment:
- https://man7.org/linux/man-pages/man3/clock_gettime.3.html
- https://docs.kernel.org/core-api/timekeeping.html
- https://www.kernel.org/doc/html/latest/admin-guide/sysctl/kernel.html
- https://www.w3.org/TR/webrtc/
- https://developer.mozilla.org/en-US/docs/Web/API/RTCCertificate
- https://developer.mozilla.org/en-US/docs/Web/API/RTCCertificate/getFingerprints

- https://api.dart.dev/dart-io/RandomAccessFile/lock.html
