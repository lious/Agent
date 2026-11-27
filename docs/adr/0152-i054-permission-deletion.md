# ADR 0152 — Official I-054 PermissionBroker refusals and export/delete barrier

## Status

Accepted for Increment 2.53 as the first I-054 slice. I-054 moves planned → partial and is not marked complete. I-029 stays partial and is not re-qualified: this increment does not rewrite `DeletionBarrier` in `packages/studio_context`. I-027 session-search leftovers are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, and V-020 stay partial and are not marked complete. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. This increment does not claim production FTS/RAG, a provider remote-deletion guarantee, a real OS permission API, or V-022 regional/network qualification.

## Decision

s12b defines `PermissionBroker.request(scope: pick|savePhoto|recordMic|readExternal|modelDownload|cloudUpload, ...) -> Grant|Denied|Cancelled`. Denied photos or microphone must not block local file import. Export to a local FileToken does not require album write permission. Denoise or clone cannot open the microphone without an informed user grant. A system picker or cloud-album retrieval is not consent to give media to an AI provider. An offline switch forbids business cloud upload. Grants stay in the local secure store and are not written into a project pack. Capture state is not a Project revision bump.

s10a and s5d require a forgetting barrier on export and diagnostic surfaces that is distinct from the I-029 intent-ledger `DeletionBarrier`: purge of a body also excludes it from summary, FTS/embedding, diagnostic export, and archive packs; an old summary cannot be published after the privacy epoch changes; an old pack that still carries a purged fingerprint cannot be imported back as live content (`SNAPSHOT_PRIVACY_BARRIER`). Default diagnostics contain no private text or source media. A "production basis" export may include policy/facts/assessment but never credentials, private contracts, or deleted bodies. Default project packs keep `sessionPolicy=excluded`. This is a protocol tombstone ledger, not production FTS/RAG.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_privacy/lib/privacy_service.dart`:

- `PermissionBroker.request` returns `grant`, `denied`, or `cancelled`. Denied `savePhoto` / `recordMic` still allow `importLocalFile`. `exportToFileToken` does not require an album grant. `startCapture` without a microphone grant is `PERMISSION_DENIED`. Treating a system grant as provider consent is `UPLOAD_CONSENT_REQUIRED`. Offline `cloudUpload` is denied. A cloud-album fetch is not `strictlyOfflineClaimed`. A grant is not written into a project pack. The broker does not submit.
- `PrivacyService.purge` advances `privacyEpoch`. Purged phrases are not visible on `fts`, `rag`, `summary`, or `archive` surfaces. Publishing a pre-purge summary or importing an old pack with a purged fingerprint is `SNAPSHOT_PRIVACY_BARRIER`. Default `exportDiagnostic` refuses private text, source media, and credentials. `exportProductionBasis` may include policy facts but refuses credentials, deleted bodies, and a non-excluded session policy. `productionFtsEnabled` and `productionRagEnabled` stay false. Remote erasure is not claimed.

The I-029 `DeletionBarrier` in `packages/studio_context` is not rewritten. Real OS permission APIs, V-022 regional/network allowlists, forensic SSD/WAL erase, and production FTS/RAG GC remain unopened.

## Consequences

The first I-054 leftover acceptance items (photo/microphone refusal still allows file import, deleted content cannot resurrect on FTS/RAG/summary/archive surfaces at this protocol bound, and default diagnostics exclude private text/media) are officialized. Production FTS/RAG is not claimed, so I-054 stays partial and is not marked complete. 87-task counts become 0 complete / 44 partial / 30 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i054-permission-deletion/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not re-qualify I-029 or I-027 leftovers. Do not claim production FTS/RAG. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not start I-035 as a product loop or claim a V-020 precision/recall achievement. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, or V-020 complete.
