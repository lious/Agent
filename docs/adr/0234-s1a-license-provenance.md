# ADR 0234 — Official s1a provenance: transforms must not wash upstream conditions, a model name is not a file hash, and a request must not self-select a personal exemption

## Status

Accepted for Increment 3.35 as a distinct already-specified s1a leftover, preferred after Increment 3.34 LLM-path work: quantize, LoRA, merge, or rename must not wash away upstream license conditions; a model name must not substitute for a file hash; and an operator role must be issued by trusted configuration, not by a request that self-selects a personal exemption. This is not an I-013 packing or archive slice, not an I-002 measurement claim, not a drop-frame or LLM-path leftover, and not a license-execution leftover already officialized in Increment 3.32. I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increments 3.06 / 3.18 / 3.20 / 3.24–3.30, and the Increment 3.32 s1c license-execution append) is kept at the start and is not silently rewritten or cleared; an s1a provenance note is appended only because I-013 already records redistribution-inventory adjacency, not because this increment re-opens packing or archive admissions or officializes s5d “再分发/执行许可分开.” I-033, I-058, I-053, I-002, I-004, I-005, I-029, and I-040 task-status are not rewritten. This does not re-qualify I-033 (idempotent POST, unknown no-blind-retry, late cancel, 费用/上传/肖像同意不能被许可warning豁免, or the standing “不代表许可grant” scope limit, including grantRef/verified writeback). It does not re-qualify I-058 (a license warning is not a release hard-block and does not exempt V-022). It does not re-qualify I-053 `WARNING_DOES_NOT_EXEMPT`. It does not re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. Increment 3.32 LicenseExecutionAdmission is not re-qualified. The s5d “再分发/执行许可分开,” “禁止标合法自包含,” and “模型引用不自动下载” sentences are not officialized here. ADR 0001 `allow_with_warning` is not re-stated as a new default. The nearby s1a sentences “输出不保证独占/可版权/不侵权” and “可信AppProfile商业角色不可被LLM/外部Skill/个人模式降级” are not officialized here. Quote/apply is not started. No paid API is called. A LoRA, training, or quantizer runtime is not invented. Increments 3.31 ErrorClassAdmission, 3.33 DropFrameAdmission, and 3.34 LlmPathAdmission are not re-qualified. I-013 job archival is not invented. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-002, I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s1a states that quantization, LoRA, merge, or rename must not wash away upstream license conditions; that a model name must not substitute for a file hash; and that an operator role is issued by trusted configuration and a request must not self-select a personal exemption. The I-033 consent-exemption and grant, I-058 V-022, I-053 fee-exemption, Increment 3.32 execution (auto-switch / HTTP 403 relabel / fact-change cancel), and s5d redistribution-fact sentences are not taken here.

This increment officializes only those s1a provenance and role-exemption bounds as a DEV-PURE compiler at the official entry path `packages/studio_license_provenance_probe/lib/license_provenance_admission.dart`:

- `licenseProvenance` is admitted (`upstreamConditionsPreserved=true`, `modelNameUsedAsHash=false`, `roleIssuedByTrustedConfig=true`, `personalExemptionSelfSelected=false`).
- An unknown kind is `LICENSE_PROVENANCE_KIND_UNKNOWN`.
- Washing upstream conditions by quantize, LoRA, merge, or rename is `UPSTREAM_CONDITIONS_WASHED`.
- Substituting a model name for a file hash is `MODEL_NAME_NOT_HASH`.
- An operator role not issued by trusted configuration is `ROLE_NOT_TRUSTED_CONFIG`.
- A request that self-selects a personal exemption is `PERSONAL_EXEMPTION_SELF_SELECTED`.
- `i033Requalified`, `i058Requalified`, `i053WarningExemptRequalified`, `fontRedistributionRequalified`, `modelsReferencedRequalified`, `licenseExecutionRequalified`, `quoteApplyStarted`, `paidApiCalled`, `allowWithWarningRestated`, `jobArchivalInvented`, `loraRuntimeInvented`, `llmPathRequalified`, `dropFrameRequalified`, and `errorClassRequalified` stay false.

`tools/spikes/license_provenance/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-033, I-058, I-053, Increment 3.32, and `resource_closure.dart` suites are not rewritten.

## Consequences

The s1a provenance and role-exemption bounds are officialized at this admission. I-013 remains partial; this increment does not mark I-013 complete and does not invent job archival. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/s1a-license-provenance/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this license-provenance admission, Increment 3.32 LicenseExecutionAdmission, I-033, I-058, I-053 `WARNING_DOES_NOT_EXEMPT`, `FONT_REDISTRIBUTION_FACT`, or `MODELS_REFERENCED_NOT_DOWNLOADED`. Do not start quote/apply or paid APIs. Do not take s5d “再分发/执行许可分开.” Do not re-state ADR 0001 `allow_with_warning` as a new default. Do not invent a LoRA, training, or quantizer runtime. Do not re-qualify Increments 3.31–3.34 I-002 admissions or claim the remaining I-002 measurement labels. Do not return to the exhausted I-013 packing / session / omitted-history cluster or Increments 3.27–3.30 archive-bound slices. Do not invent I-013 job archival. The s1a sentences “输出不保证独占/可版权/不侵权” and “可信AppProfile商业角色不可被LLM/外部Skill/个人模式降级” remain unofficial.
