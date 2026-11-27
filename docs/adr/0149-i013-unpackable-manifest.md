# ADR 0149 — Official I-013 unpackable-resource explicit manifest

## Status

Accepted for Increment 2.50 as the leftover I-013 clause 「不可打包资源显式manifest」. I-013 stays partial. I-037, I-038, and V-007 stay partial and are not marked complete. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. Job archival and pending-job reports are not invented. 「取消无半包发布」 and 「保留策略不删可达blob」 are not re-qualified. A 60s WebCodecs/OPFS roundtrip is not claimed.

## Decision

s5d says originals / proxies / linked are export modes. proxies packs only available proxies and mappings, sets `manifest.packMode=linked`, and lists missing original Asset IDs in `missingExternalRefs`. linked packs only the document and selected small resources; external locators keep IDs only and need a relink on another machine. The 2.0 `packMode` enum stays `embedded` or `linked`; `proxyOnly` is not invented as a packMode. `sourceCompleteness` is `selfContained`, `proxyOnly`, `externalRefs`, or `incomplete`. A package is `selfContained` only when every required edit/render source, including an available font closure, is present; finishing a ZIP is not enough. Model reproduction gaps are reported as `omission.impact=reproGeneration` and do not pretend cloud models or weights were packed.

This increment officializes that bound on the already-admitted `ProjectArchive`:

- `save(..., options: ArchiveOptions(mode: linked|proxies))` publishes `packMode=linked` with an explicit `missingExternalRefs` list and does not pack omitted originals.
- `sourceCompleteness` is computed on `VerifiedArchive`. A linked package is never `selfContained`. proxies mode without available proxies is `incomplete`, still with `packMode=linked`.
- Opening a linked package sets `needsRelink=true` and does not call `requireLocalEditingWritable`. External locators are not fetched.
- A planted `packMode=proxyOnly` is `ARCHIVE_VERSION_UNSUPPORTED`. The default originals `save` path stays embedded, still refuses a non-null locator as `FEATURE_NOT_IMPLEMENTED`, and is not rewritten.
- Session policy stays `excluded`; `sessionArchive` stays null.

The Increment 1.92 I-013 and Increment 1.93 I-014 official suites were re-run, not rewritten.

## Consequences

The leftover I-013 remainingAcceptance item 「不可打包资源显式manifest」 is officialized at this bound. 「运行job归档固定rev并报告pending」 remains unopened. I-013 stays partial. 87-task counts stay 0 complete / 42 partial / 32 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i013-unpackable-manifest/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent job archival unless that slice is already specified and can be officialized without a paid-job coordinator. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, or V-007 complete.
