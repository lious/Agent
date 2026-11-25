# ADR 0008 — Browser WebRTC identity and bounded indexed source thumbnails

Date: 2026-11-25 Asia/Shanghai. Status: implemented restricted slice, NOT full qualification.
Original104 exports and original87 acceptance/scope/dependencies are unchanged. This
adds evidence to I-021 and XD-001/002/003/005/006/007/009, not new product scope.

## Browser security and integration decision

Use browser-standard ECDSA P-256 RTCCertificate + native browser DTLS/SCTP rather
than an unauthenticated HTTP endpoint, plaintext WebSocket, native-mTLS imitation,
or custom crypto. Structured-clone the browser certificate HANDLE in actual
IndexedDB; racing creation rechecks atomically, reload retains fingerprint, expiry
fails closed. No PEM/key export API, plaintext-key fallback or OS-key-store claim.
Origin storage/XSS/eviction remain browser trust boundaries, NOT hardware security.
Losing identity never resumes old coordinator authority or grants.

Manual full offer/answer JSON exchange is signaling only: no cloud signaling,
STUN/TURN, paid relay or default material upload. Confirm remote FULL SHA256 by an
independent trusted channel; an SDP-provided fingerprint alone is NOT identity.
Pin every SDP fingerprint before setRemoteDescription, application-only host ICE;
reject SHA1, mismatched pins, relay/srflx/ice-lite and oversized/duplicate JSON.
Bound queues/pending/buffered frames; close has no unauthenticated fallback.
Address-bearing SDP is public signaling but should only go to the approved device.

Browser coordinator uses ORIGINAL HarnessPlan/SessionRef/VerifiedDevice/placeTask/
TaskLease/LeaseState/BuiltinCompute and original eight-field peer request shape.
Atomic IndexedDB projects+peer_runtime transaction commits authorization checks,
receipt and candidate outbox together. This is a browser persistence ADAPTER,
not a second incompatible scheduler or SQLite WASM claim. Two frozen, free,
metadata-only digest nodes; project revision stays unchanged. Remote node scope,
full fingerprint, epoch, boot/fence, attempts, lease expiry, hash/schema pins,
heartbeat progress, quotas and namespace device reservations fail closed.
Permissions are checked before cached replies. Session revoke also denies local
work. Hidden tabs or backward clocks suspend; ten-minute wall limit; no automatic
restart authority. Foreign-boot resource reservations are conservative, not
silently released using a new clock. No signed live resource attestation or
physical-host-global resource arbitration is claimed.

## Actual bounded qualification result: blocked positive WebRTC

Real Chrome completed ICE gathering with **zero host candidates on BOTH peers**;
no DTLS/SCTP connection or encrypted task exchange succeeded. Managed policy keys
observed locally: `WebRtcIPHandlingUrl` has `disable_non_proxied_udp` for `*`;
`WebRtcIPHandling` is `default_public_interface_only`. Only these relevant keys
were inspected; no credentials or other device/user material. No policy edits,
privacy-evading browser flags, camera/mic prompts, alternate lower-level transport,
STUN/TURN/proxy/relay or deployment were used to bypass this restriction.

The app now closes and shows `RTC_DIRECT_CANDIDATES_UNAVAILABLE`; this is a REAL
fail-closed preflight, NOT a passing positive network test. Positive tests remain
explicit in `apps/studio_web/test/qualification/rtc_direct_qualification.dart`;
`run_web_rtc_qualification.py` returns2 for blocked preflight, never success.
Ordinary Chrome tests exercise real certificate persistence, real IDB legacy
migration/rollback/lease/result transactions and actual clickable UI; they are
explicitly NOT encrypted-network qualification. Historical failed experiments
remain in evidence. This environmental restriction blocks qualification, not a
claim that the adapter/native bridge/worker outbox is complete.

Still missing: browser↔native WebRTC bridge, worker durable pending-result outbox
and reconnect, browser explicit coordinator authority recovery, Web blob transfer,
certificate rotation UI, broad device telemetry/media/model execution, physical
multi-device and non-Linux/browser matrix. Same-box tests cannot close XD-010.

## Source preview decision and exact scope

Add additive `sm_preview` ABI1 capability `sourcePreview128`; old ABI1 libraries
without capability are explicitly rejected. Actual FFmpeg avformat_seek_file
container index + decoder flush + decode-forward selects by exact source PTS,
relative to FIRST source PTS; no nominal-fps approximation. Sequential decode is
an independent reference path, not a fake seek implementation. Max128-edge RGBA
thumbnail; Rec709 limited YUV420P8, one video stream, local files, bounded frame
size/recipe/packets, native cancellation epoch and RAII. Not GPU/effect/timeline
preview, proxy generation or broad format qualification.

SDK verifies CAS before decode, serializes preview requests on a SEPARATE native
handle so preview cancellation does not call the export handle, rejects late
requests/project drift/close, and caches immutable RGBA with 2MiB retained-pixel
LRU/256 entries (max configurable64MiB). Pixel lengths/range are validated before
allocation. This is NOT a total RSS/disk/SQLite cap. UI source-time seek renders
real pixels and clears old thumbnail after edit/selection change.

Actual20 shuffled CFR positions assert exact rational requested timestamp and
pixel/PTS equality against full sequential decode; indexed packet count is lower
on at least one GOP fixture. Real generated nonzero-start and VFR sources are
checked (including known VFR PTS), as are EOF/multistream/HDR rejection, stale
queue/project/close, byte budget/entry cap/immutability and UI click path. VFR
SDK project import/export is STILL rejected; low-level preview qualification does
not silently widen the editor's CFR-only scope. Mid-seek cancellation latency,
proxy source mapping and actual A/V clock/load qualification remain open; I-021
and V-004 full-task completion is not claimed. No AAC/audio export this batch.

## Official sources opened this batch

- https://developer.mozilla.org/en-US/docs/Web/API/RTCCertificate — serializable
  certificate, fingerprints and expiry; NOT a human identity or hardware guarantee.
- https://developer.chrome.com/docs/modern-web-guidance/guides/security/local-network-access
  — secure contexts and granular local/loopback permissions are separate platform
  requirements, NOT authorization to defeat managed ICE privacy policy.
- https://issuetracker.google.com/issues/421223919 — prior researched Chrome LNA
  context; no claim this issue alone diagnoses current managed-policy suppression.
