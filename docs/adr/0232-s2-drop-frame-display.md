# ADR 0232 — Official s2 drop-frame timecode only changes display numbering and must not delete media frames

## Status

Accepted for Increment 3.33 as a distinct already-specified s2 leftover, looked up more broadly after I-013 packing / archive slices, I-002 error-class work, and Increment 3.32 s1c license-execution: drop-frame timecode only changes display numbering and must not delete media frames. This is not an I-013 packing or archive slice, not an I-002 measurement claim, and not a license-execution leftover. Existing I-002 remainingAcceptance wording still starts with the four original labels (`1万次有理运算/往返无漂移；非法FK/交叠/overflow全拒；现有合成项目通过；结构与业务错误分开。`) and the Increment 3.31 error-class append, and is not silently rewritten or cleared; a drop-frame note is appended only. The remaining I-002 measurement labels stay listed and unclaimed. Increment 3.31 ErrorClassAdmission is not re-qualified. Increment 3.32 LicenseExecutionAdmission, I-033, I-058, I-053 `WARNING_DOES_NOT_EXEMPT`, `FONT_REDISTRIBUTION_FACT`, and `MODELS_REFERENCED_NOT_DOWNLOADED` are not re-qualified. I-013 remainingAcceptance wording (including the Increment 3.32 append) is not rewritten. I-033, I-058, I-053, I-004, I-005, I-029, and I-040 task-status are not rewritten. I-010 sidecar / `SUBTITLE_TIMECODE` work is not re-qualified. A drop-frame converter, text shaper, or caption burn-in path is not invented. Source-interval crop and MP4/preview burn-in stay closed. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. The closed root is not extended. Unknown fields are not swallowed. I-002, I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s2 states that drop-frame timecode only changes display numbering and must not delete media frames. The same paragraph’s rational-second truth, per-frame / per-sample time formulas, sequence-frame vs sample-grid edit bounds, and “audio is not forcibly rounded to video frames” sentences are not officialized here and are not used to claim the remaining I-002 measurement labels or a 20ms A/V achievement. Already-official “timeline time does not use wall clock” bounds in earlier clock ADRs are not re-qualified.

This increment officializes only that drop-frame display bound as a DEV-PURE compiler at the official entry path `packages/studio_drop_frame_probe/lib/drop_frame_admission.dart`:

- `dropFrameDisplay` is admitted (`displayNumberingOnly=true`, `mediaFramesDeleted=false`).
- An unknown kind is `DROP_FRAME_KIND_UNKNOWN`.
- Treating drop-frame timecode as deleting media frames is `DROP_FRAME_DELETES_MEDIA`.
- `rationalOpsRequalified`, `fkOverlapOverflowRequalified`, `syntheticProjectRequalified`, `errorClassRequalified`, `licenseExecutionRequalified`, `captionTimecodeRequalified`, `closedRootExtended`, `unknownFieldsSwallowed`, `dropFrameRuntimeInvented`, and `shaperInvented` stay false.

`tools/spikes/drop_frame/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-002 error-class, I-010 caption, and rational-time suites are not rewritten.

## Consequences

The s2 drop-frame display bound is officialized at this admission. I-002 remains partial; this increment does not mark I-002 complete and does not claim 10k rational roundtrips, illegal FK/overlap/overflow refusal, or existing synthetic-project passage. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i002-drop-frame/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this drop-frame admission, Increment 3.31 ErrorClassAdmission, or Increment 3.32 LicenseExecutionAdmission. Do not claim the remaining I-002 measurement labels. Do not return to the exhausted I-013 packing / session / omitted-history cluster or Increments 3.27–3.30 archive-bound slices. Do not invent I-013 job archival. Do not start quote/apply or paid APIs. Do not invent a drop-frame converter or text shaper. s1a sentences such as “量化、LoRA、合并、改名不洗掉上游条件,” “模型名称不替代文件hash,” and “经营角色由可信配置签发，不允许请求自己选个人豁免” remain distinct leftovers only if they can be bounded without re-qualifying I-033, I-058, `FONT_REDISTRIBUTION_FACT`, or `MODELS_REFERENCED_NOT_DOWNLOADED`. s2 “路径不能来自LLM” also remains unofficial.
