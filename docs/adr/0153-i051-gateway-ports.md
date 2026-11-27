# ADR 0153 — Official I-051 GatewayPorts keys, tenant ACL, and signed-URL rules

## Status

Accepted for Increment 2.54 as the first I-051 slice. I-051 moves planned → partial and is not marked complete. V-021 stays blocked; this increment does not claim a serverless qualification or deploy a backend. I-054 and I-029 are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, and I-054 stay partial and are not marked complete. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. This increment does not select or deploy a vendor, does not call a paid API, and does not invent a PostgreSQL or object-store persistence schema.

## Decision

s10h says the App does not depend on a server by default. When a cloud path is used, namespace is mapped from the authenticated `appId` / `tenantId` / `workspaceId`, and a model-supplied tenant is ignored. Object keys are random and namespace-isolated. Content-hash dedup must not leak whether another tenant has the same file. Tokens and secrets live in a server key store or the App's OS-secure store, and never enter a project pack or session export. `GET /v1/artifacts/{id}/grant` is a short-lived, ACL-checked object grant. Event cursors do not place a token in the URL. Business functions do not forward large media; clients upload to a signed object URL. I-051 acceptance requires measurable URL expiry and reuse rules, zero cross-tenant access, and upload consent. The official profile is local simulation first; the cloud is not used to auto-fetch user media.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_gateway/lib/gateway_ports.dart`:

- `GatewayPorts` never reports keys in the App, a project pack, or a session export. `putViaBusinessFunction` is `MEDIA_NOT_PROXIED`. `fetchUserMediaViaServerless` is `TOOL_NOT_ALLOWED`. Event cursor URLs do not include a token. The App still runs when `cloudEnabled` is false.
- `issueUploadGrant` uses the authenticated tenant. A mismatched model-claimed tenant is `TENANT_DENIED`. Missing upload consent is `UPLOAD_CONSENT_REQUIRED` with `networkRequestCount=0`. `hasObject` only reports hashes stored for that tenant, so another tenant's same-hash object is not leaked. `useGrant` after expiry is `URL_EXPIRED`; a second use past `maxUses` is `URL_REUSED`; a wrong-tenant grant is `TENANT_DENIED`. `crossTenantAccessCount` stays 0. No paid API is called, and the port does not submit.

I-028 / I-033 / I-054 upload-consent leftovers are not re-qualified. A real FastAPI + PostgreSQL + object-store deployment remains unopened.

## Consequences

The first I-051 leftover acceptance items (business functions do not forward large media, cross-tenant access is 0, URL expiry and reuse are testable, keys do not enter the App or project, and upload requires consent) are officialized at this local-simulation bound. V-021 stays blocked, so I-051 stays partial and is not marked complete. 87-task counts become 0 complete / 45 partial / 29 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i051-gateway-ports/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents, for example a narrowly specified I-046 ASR-proposal refusal bound if it can be officialized without real on-device inference. Do not re-qualify I-051, I-054, or I-029. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not start I-035 as a product loop or claim a V-020 precision/recall achievement. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, or I-051 complete.
