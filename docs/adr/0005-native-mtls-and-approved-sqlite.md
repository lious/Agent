# ADR 0005 — Native authenticated direct execution and approved SQLite source

Status: implemented bounded native integration, not production/all-platform qualification.
Date: 2026-11-25, Asia/Shanghai. Requirements: t82/t83/t84; original 104 export files unchanged.

## Choice and threat boundary

Use Dart SDK SecurityContext/SecureSocket/HttpServer HTTPS and mature CA-validated TLS (minimum1.2), NOT custom encryption. Client additionally checks the exact SHA256 leaf certificate over DER inside official `HttpClient.connectionFactory`, BEFORE the SDK may emit HTTP headers/body. No `badCertificateCallback`, first-use trust, certificate bypass, HTTP downgrade, redirect, proxy, public discovery, cloud data upload or paid relay.

Native transport is isolated in `studio_peer_io`; Web/pure packages never import it. Web browsers cannot programmatically install client TLS identity with this API. A browser-compatible authenticated transport and OS identity-store adapters are still required; this does NOT claim all six platform targets can pair today.

No anonymous administrative route exists. Locally create an expiring <=5min offline offer AFTER external full-fingerprint comparison and host runtime qualification, then locally confirm exact fingerprint once. Grant <=24h is namespace/session/immutable-plan/node scoped, persisted with epoch. Local revoke is idempotent and increments epoch once; regrant increments again. A fingerprint string is NOT authentication: only verified socket client certificate may select that ACL. Local methods are not exported as RPC.

Current identity keys are supplied through host-owned SecurityContext. Tests create ephemeral OpenSSL CA/leaf keys in0700 temporary directory with0600 keys and delete them. The development worker's PEM arguments are test-only; OS secure identity provisioning and pairing UI are NOT implemented or qualified. Do not expose a production endpoint from this increment.

## Same-session execution and failure semantics

Only original frozen PlanGraph's already supported free builtins execute; no remote shell, paid/model handler, direct project edits, arbitrary file path or local media-library enumeration. Grant-approved node inputs must match exact frozen content hash; output schema is a pinned closed builtin schema and result hash/source/certificate/bound epoch/fence must match. Hashes give integrity and provenance, NOT a proof that an authorized compromised worker computed honestly.

Every operation/replay rechecks current grant, expiry, node/plan scope, coordinator boot and base project revision. Request ID/hash/response, task lease/binding and outbox are one SQLite transaction via nested savepoints. Cached claims derive fresh remaining duration and reject expired/replaced/terminal leases; they cannot mint extra lease time. Wall-clock high-water persists even for rejected expired grants, preventing grant resurrection after clock rollback. Revocation denies existing keepalive TLS connections; occupied devices remain reserved until lease expiry, not a fictitious stop ACK.

One heavy slot/device is enforced transactionally within a namespace across its plans. Cross-namespace/global host resource arbitration, live signed capability/thermal/load telemetry and full privacy/rights/budget epoch ledger remain. Trusted host registry values are not raw peer self-advertisements.

Coordinator takeover is LOCAL owner administration, not a peer operation: expected-boot CAS, durable operation receipt, unique new boot (no ABA), preserved attempts/cancel state and budget. A host-measured conservative upper bound of unobserved elapsed time is charged; unknown duration exhausts remaining wall budget. Old boot cannot commit. Per-attempt hard timeout also persists: repeated heartbeat may not stretch a node beyond its deadline. v4 active leases migrate conservatively with their known lease cutoff. Old device is quarantined for conservative residual lease duration, carried even through repeated takeovers after a node was reassigned; upper-bound downtime is deliberately NOT subtracted as if it proved a minimum time elapsed. This API is not automatic distributed leader election or remote authority delegation.

## SQLite runtime correction

Official WAL documentation says WAL-reset affects3.7.0–3.51.2, fixed3.51.3+, with specific3.44.6/3.50.7 backports. System3.46.1 was historical DEV evidence and never qualifies by passing generic tests. Pin official3.54.1 source (also includes reported32-bit fix), exact published SOURCE_ID and SHA3-256 of sqlite3.c. `tools/bootstrap_sqlite.py` verifies source before compiling isolated Linux library; no system library replacement. Compile THREADSAFE=1; check actual loaded version/source/thread option BEFORE repository pragmas/migrations by default. Explicit `allowUnqualifiedSqliteForDevelopment` is a non-qualifying escape hatch, not a production pass.

`verify_sqlite_upgrade.py` really executes original committed v4 store code under old system SQLite, closes it, then current v5 store under approved library and checks preserved project/integrity/schema. Current code rejects old runtime by default. This is real library compatibility evidence, not an App UI or physical power-loss test. WAL files must stay host-local, not shared over a network filesystem; never run mixed runtime versions concurrently against the same database.

## Qualification limits and sources

Real loopback TCP/TLS, CA-negative and exact-pin-negative tests, same-session native child workers, SQL fault rollback, grant revoke/replay/expiry, late results and restart fencing are protocol integration on ONE Linux host. Not physical-device/LAN/NAT/Internet, browser transport, mobile background, OS keystore, paid/model execution or production release qualification.

Official sources opened this turn:
- https://api.dart.dev/dart-io/HttpServer/bindSecure.html
- https://api.dart.dev/dart-io/HttpRequest/certificate.html
- https://api.dart.dev/dart-io/HttpClient/connectionFactory.html
- https://api.dart.dev/dart-io/ConnectionTask-class.html
- https://api.dart.dev/dart-io/SecureSocket/startConnect.html
- https://sqlite.org/wal.html#the_wal_reset_bug
- https://sqlite.org/changes.html (3.54.1 SOURCE_ID / source SHA3)
