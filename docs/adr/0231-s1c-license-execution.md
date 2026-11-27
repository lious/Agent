# ADR 0231 — Official s1c license gaps must not auto-switch models, relabel HTTP 403 as a license warning, or let a fact-only change cancel jobs or trigger a paid retry

## Status

Accepted for Increment 3.32 as a distinct already-specified s1c leftover, looked up more broadly after I-013 packing / archive slices and I-002 error-class work: a commercial-license gap must not automatically switch models; an HTTP 403 must not be relabeled as a license warning and retried; and a license-fact-only change must not cancel a running job, drop candidates, or trigger a paid retry. This is not an I-013 packing or archive slice and not an I-002 measurement claim. I-033, I-058, I-053, I-002, I-004, I-005, I-029, and I-040 task-status are not rewritten. I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increments 3.06 / 3.18 / 3.20 / 3.24–3.30) is kept at the start and is not silently rewritten or cleared; a s1c license-execution note is appended only because I-013 already records redistribution-inventory adjacency, not because this increment re-opens packing or archive admissions. This does not re-qualify I-033 (idempotent POST, unknown no-blind-retry, late cancel settles only, 费用/上传/肖像同意不能被许可warning豁免, or the standing “不代表许可grant” scope limit). It does not officialize grantRef/verified writeback. It does not re-qualify I-058 (a license warning is not a release hard-block and does not exempt V-022). It does not re-qualify I-053 `WARNING_DOES_NOT_EXEMPT`. It does not re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. The s5d “再分发/执行许可分开” collection sentences, “禁止标合法自包含,” and “模型引用不自动下载” are not officialized here. Quote/apply is not started. No paid API is called. Increment 3.31 ErrorClassAdmission, Increment 3.30 FixedRevisionArchiveAdmission, Increment 3.04 JobCancelAdmission, and Increment 3.06 ArtifactKindAdmission are not re-qualified. I-013 job archival is not invented. ADR 0001 `allow_with_warning` is not re-stated as a new default. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-002, I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s1c states that a missing commercial authorization must not automatically switch to another model; that an HTTP 403 must not be relabeled as a license warning and retried; and that a change to commercial-license facts alone refreshes the warning/audit and must not cancel a running job, drop candidates, or trigger a paid retry. The I-033 consent-exemption, I-058 V-022, I-053 fee-exemption, and s5d redistribution-fact sentences are not taken here.

This increment officializes only those s1c execution bounds as a DEV-PURE compiler at the official entry path `packages/studio_license_execution_probe/lib/license_execution_admission.dart`:

- `licenseExecution` is admitted (`autoSwitchedModel=false`, `http403Relabeled=false`, `jobCancelled=false`, `candidatesDropped=false`, `paidRetryTriggered=false`).
- An unknown kind is `LICENSE_EXECUTION_KIND_UNKNOWN`.
- Automatically switching models because of a license gap is `LICENSE_GAP_NO_AUTO_SWITCH`.
- Relabeling an HTTP 403 as a license warning is `HTTP_403_NOT_LICENSE_WARNING`.
- Canceling a running job because license facts changed is `LICENSE_FACT_NO_JOB_CANCEL`.
- Dropping candidates because license facts changed is `LICENSE_FACT_NO_DROP_CANDIDATE`.
- Triggering a paid retry because license facts changed is `LICENSE_FACT_NO_PAID_RETRY`.
- `i033Requalified`, `i058Requalified`, `i053WarningExemptRequalified`, `fontRedistributionRequalified`, `modelsReferencedRequalified`, `quoteApplyStarted`, `paidApiCalled`, `jobArchivalInvented`, `fixedRevisionArchiveRequalified`, and `errorClassRequalified` stay false.

`tools/spikes/license_execution/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-033, I-058, I-053, and `resource_closure.dart` suites are not rewritten.

## Consequences

The s1c license-execution bounds are officialized at this admission. I-013 remains partial; this increment does not mark I-013 complete and does not invent job archival. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/s1c-license-execution/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this license-execution admission, I-033, I-058, I-053 `WARNING_DOES_NOT_EXEMPT`, `FONT_REDISTRIBUTION_FACT`, or `MODELS_REFERENCED_NOT_DOWNLOADED`. Do not start quote/apply or paid APIs. Do not take s5d “再分发/执行许可分开.” Do not re-qualify Increment 3.31 ErrorClassAdmission or claim the remaining I-002 measurement labels. Do not return to the exhausted I-013 packing / session / omitted-history cluster or Increments 3.27–3.30 archive-bound slices. Do not invent I-013 job archival. s5d “遗忘屏障与流式竞态” remains too close to I-029 DeletionBarrier.
