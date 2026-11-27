# ADR 0122 — Play LAN protocol software tests (v1.9.4)

## Status

Accepted for Increment 2.23 as a further Linux/Web software/protocol slice of the play-mode limited LAN contract. XD-010 stays blocked. Schema v10 is not merged. `fullTasksCompleted` stays 0 for both the 87-task program and the separate XD set.

## Decision

`PlayLanEndpoint` answers `snapshotRequest` with a snapshot filtered for the **requester** triple, never the answering host's notebook. `crew.confidential` and character `sides.*` stay scope-bound. An accepted `event` can be acknowledged with `eventAck`. Stale or duplicate seq is ignored. Unknown senders are `PLAY_LAN_UNKNOWN_PEER`. After `goodbye`, further messages from that peer are `PLAY_LAN_PEER_GONE`. The loopback fabric is still in-process only. `claimPhysicalE2e` remains `PLAY_LAN_PHYSICAL_E2E_UNCLAIMED`.

The frozen 2.14 `lan_protocol_test.dart` suite is not rewritten.

## Consequences

87-task counts stay 0 complete / 35 partial / 39 planned / 13 blocked. XD counts stay 0 complete / 8 partial / 1 planned / 1 blocked, with XD-010 blocked. Official new suite: 3 tests. Frozen LAN suite (4) and the rest of `studio_play` re-run. Analyzer exit 0.

## Evidence

`docs/implementation/evidence/play-lan-protocol-v194/`.

## Follow-up

Physical two-device LAN E2E, schema v10, and XD-010 remain unclaimed. Next honest Linux/Web increments include still-doable planned or remaining-partial work such as I-007 speed remapping / nest, leftover I-008 transform keyframes (Ken Burns), or I-029 intent/forgetting watermarks — all without real-device or paid-API claims.
