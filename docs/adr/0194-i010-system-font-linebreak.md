# ADR 0194 — Official s4 no platform system-font default for line breaks (I-010 leftover)

## Status

Accepted for Increment 2.95 as a distinct already-specified s4 leftover on I-010: caption layout must use an explicit fontRef or font hash, not a platform system-font default that would make line breaks differ across platforms. I-010 stays partial and is not marked complete. A text shaper is not invented. Deterministic shaping is not claimed. I-010 sidecar and font-fallback work are not re-qualified. ADR 0019, C.001, and C.002 are not rewritten and are not re-qualified. Increment 2.94 CaptionSafeAreaAdmission is not re-qualified, and the ADR 0193 inset reading of `brandPolicy.safeArea` is not re-opened. Source-interval crop and MP4/preview burn-in stay closed. Locked captions are not overwritten. Hard dependency I-005 remains partial. Increment 2.93 DownmixAdmission, I-009 mix, Increment 2.83 varispeed-and-pitch, and Increment 2.85 recording-drift are not re-qualified. Increment 2.92 PreviewExportConsistencyAdmission and Increment 2.90 RenderRecipeAdmission are not re-qualified. A FrameLease is not invented, and a V-003 measurement is not claimed. Increments 2.74–2.94 already-landed slices are not re-qualified. CompatibilityStore / ModelLease are not started. I-061, I-055, I-059, I-060, I-035, and V-024 stay planned or closed as already recorded. I-010, I-023, I-022, V-006, I-021, I-004, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 “textStyle / caption” requires `不能让各平台系统字体默认选择导致断行不同`, alongside `fontRef/hash`.

ADR 0019 already officializes a narrower identity bound: a missing font in a frozen definition gets an explicit missing marker and never a system-font lookup. C.001 and C.002 already officialize narrower ASS sidecar bounds: export requires an explicit `AssFontLayoutPolicy`, writes only a registered family name, substitutes a listed fallback (including declared script coverage) rather than keeping a missing or uncovered family, and does not claim shaping. Those consumers are not rewritten here.

This increment officializes the remaining general s4 protocol that was not a standalone admission: caption layout must name an explicit `fontRef` or font hash, and must not use a platform system-font default, because that default would make line breaks differ across platforms. This admission does not shape text, measure line breaks, or embed glyph files.

The official entry path is `packages/studio_system_font_probe/lib/system_font_linebreak_admission.dart`:

- An explicit `fontRef` or font hash is admitted (`explicitFont=true`).
- A platform system-font default, even when a `fontRef` is also supplied, is `SYSTEM_FONT_DEFAULT_FORBIDDEN`.
- Layout with neither `fontRef` nor font hash is `FONT_REF_REQUIRED`.
- `shaperInvented`, `i010SidecarRequalified`, `fontFallbackRequalified`, `captionSafeAreaRequalified`, `adr0019Requalified`, `sourceIntervalCropOpened`, `burnInOpened`, `lockedCaptionsOverwritten`, `deterministicShapingClaimed`, and `paidApiCalled` stay false.

A text shaper remains unopened. `tools/spikes/system_font_linebreak/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 “不能让各平台系统字体默认选择导致断行不同” bound is officialized at this admission. Source-interval crop, MP4/preview burn-in, and deterministic shaping stay closed or unclaimed, so I-010 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i010-system-font-linebreak/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this system-font line-break admission, Increment 2.94 CaptionSafeAreaAdmission, or I-010 sidecar/font-fallback work. Do not invent a text shaper, do not open source-interval crop or MP4/preview burn-in, and do not claim deterministic shaping. Do not re-open the ADR 0193 inset reading of `safeArea`. I-005 remains a hard dependency, so I-010 must not be marked complete.
