# ADR 0158 — Official I-056 diagnostic and trace redaction

## Status

Accepted for Increment 2.59 as the first I-056 slice. I-056 moves planned → partial and is not marked complete. This increment does not re-qualify I-054 default-diagnostic exclusions or I-029 DeletionBarrier: those already officialize pack-level exclusion of private text, source media, and credentials, and the deletion barrier on FTS/RAG/summary/archive. I-056 is a distinct observability bound. Production FTS/RAG is not claimed. I-055 LocaleCatalog/a11y work is not started. I-053 and I-033 leftovers are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, and I-053 stay partial and are not marked complete. V-009, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. A telemetry backend is not invented or required. Logs are not uploaded by default.

## Decision

s12d defines `DiagnosticExporter`: the default local ring is a structured-field whitelist of opaque run/job/command IDs, pack/operator/build versions, stage/errorCode, a coarse device tier, and latency/peak/thermal summaries. Bodies, chain-of-thought, audio/video, source paths, filenames, EXIF GPS, person embeddings, secrets, signed URLs, and store tokens are excluded. Users preview the export list and pick a destination after redaction; upload needs a separate grant. Crash/analytics stay unconnected by default. If redaction cannot be proved, the payload stays local and is not sent. Deleting a session, source, or voice clears related diagnostic bodies and must not revive them for debugging. s10h requires `traceId→run/plan/node/attempt/providerJob` correlation, and that logs keep hashes, meters, and status rather than media bodies. I-056 acceptance further requires that identifiable original-image hashes are filtered per the privacy configuration, that a fault trace can join revision and job, and that a duplicate event does not double-count cost. Outbound diagnostics require explicit user consent. A missing telemetry backend must not block local use.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_quality/lib/trace_viewer.dart`, exported alongside the existing V-020 baseline (which is not rewritten):

- `TraceViewer.export` keeps the official whitelist and, when `PrivacyRedactionConfig` filters are on (the default), omits secrets, prompt bodies, chain-of-thought, person embeddings, identifiable original-image hashes, source paths, filenames, EXIF GPS, signed URLs, store tokens, and canary emails. Synthetic canary values must not appear in the export payload.
- A recorded fault event preserves `traceId` together with `runId`, `planId`, `nodeId`, `attempt`, `providerJobId`, `jobId`, and `revision`. Local export works when no telemetry backend is present. `defaultLogUpload` stays false. Upload without consent is `UPLOAD_CONSENT_REQUIRED`. Upload when redaction cannot be proved is `REDACTION_UNPROVEN` and stays local.
- Cost is summed once per `eventKey`; a repeated status event does not double-count. `purgeDiagnosticBodies` clears related records so they cannot be revived for debugging. `crashSdkConnected`, `paidApiCalled`, `submitted`, `productionFtsEnabled`, and `productionRagEnabled` stay false. Compile does not write a project document.

A production trace service, CrashSDK/analytics integration, and a live export UI remain unopened. This is not a rewrite of `PrivacyService.exportDiagnostic`.

## Consequences

The first I-056 leftover acceptance items (secrets/bodies/embeddings/identifiable original-image hashes are filtered per the privacy configuration, a fault trace can join revision and job, and a duplicate event does not double-count cost) are officialized at this TraceViewer bound. The remaining scope (a richer local trace/run/job/cost board and a user-facing export preview) is only opened at this compiler bound; default log upload stays off. I-056 stays partial and is not marked complete. 87-task counts become 0 complete / 50 partial / 24 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i056-trace-redaction/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not re-qualify I-056, I-054 default-diagnostic exclusions, or I-029 DeletionBarrier. Do not claim production FTS/RAG. Do not start I-055 unless a narrowly scoped already-specified piece is required. Do not invent a payment vendor, connect StoreKit/Play, or claim V-022. Do not re-qualify I-053 or I-033 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not start I-035 as a product loop or claim a V-020 precision/recall achievement. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, or I-056 complete.
