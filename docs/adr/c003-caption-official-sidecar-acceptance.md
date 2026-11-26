# ADR C.3 — Official I-010 sidecar acceptance: overlap path, unsupported-style loss report, and format goldens

## Status

Accepted for captions-side Increment C.3 as the official-acceptance block for already-opened SRT/VTT/ASS sidecar import and export (s3 / s8r / s12d). This identifier continues the captions-side C.x series and does not occupy mainline 1.xx. Increment C.1 and C.2 evidence remain in evidence/caption-ass-export and evidence/caption-font-coverage-fallback. I-005 and I-010 remain partial. This increment does not claim I-010 complete, does not claim deterministic font shaping or bidi layout, and does not claim lossless roundtrip of arbitrary ASS effects. Already-delivered `AssFontLayoutPolicy` name fallback, declared script coverage, `ASS_EXPORT_FONT_POLICY_REQUIRED`, `ASS_FONT_UNAVAILABLE`, `ASS_FONT_SUBSTITUTED`, `ASS_LAYOUT_MAY_CHANGE`, `ASS_FONT_COVERAGE_SUBSTITUTED`, `ASS_FONT_COVERAGE_UNAVAILABLE`, `SetCaptions(automatic: true)` `MANUAL_FIELD_LOCKED`, `CAPTION_OVERLAP`, and `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED` stay unchanged. Official InversePatch `kind` stays `restoreSnapshot`. Source-interval crop and MP4/preview text burn-in stay closed.

## Context

I-010 acceptance requires emoji/RTL/newline/non-frame timecode roundtrip, a warning (not a silent drop) for unsupported styles, and a determined overlap policy. The overlap policy itself was already a deterministic `CAPTION_OVERLAP` reject of intersecting half-open ranges, enforced when constructing `CaptionStore` and therefore also when `CaptionFormats.decode` wraps a `CaptionImport`. Official format, persist, and workbench import of an overlapping sidecar, and overlap against already-committed project cues, had not been qualified as official paths with evidence. Spec 8r also requires SRT/WebVTT non-overlap validation and an ASS/SSA supported-subset loss report: static Style properties other than a listed `Fontname` and Dialogue fields outside the supported subset (`Layer` other than 0, actor `Name`, per-event margins, `Effect`) could be dropped without a dedicated warning.

## Decision

The overlap policy does not change: intersecting half-open cue ranges remain `CAPTION_OVERLAP`; touching ranges remain allowed. Official paths that must exhibit this policy are format decode (`CaptionFormats.decode` via `CaptionImport` / `CaptionStore`), the SDK persist path (`StudioWorkspace.importCaptions` / `SetCaptions`), and the workbench import controls. An overlapping sidecar is refused as a whole file with no partial commit. A sidecar whose cues overlap already-committed project cues is likewise refused and leaves the revision unchanged.

Unsupported ASS Style properties other than `Name` and `Fontname` are listed as `ASS_STYLE_FIELDS_DROPPED`. Unsupported Dialogue style-bearing fields are listed as `ASS_EVENT_STYLE_DROPPED`. Existing `ASS_STYLE_FONT_NOT_RENDERED`, `ASS_OVERRIDE_DROPPED`, `ASS_EVENT_DROPPED`, `WEBVTT_METADATA_DROPPED`, `WEBVTT_CUE_SETTINGS_DROPPED`, and `SUBTITLE_MARKUP_DROPPED` warnings stay. These warnings are a loss report for the supported static subset; they do not map those fields onto the plain cue model, do not open `styleEffectId`, and do not claim lossless ASS effects or shaping.

Checked-in goldens under `packages/studio_document/test/captions/formats/goldens/` freeze official SRT/VTT (millisecond, including 101 ms non-frame times) and ASS (exact centiseconds) sidecar text for emoji, RTL, newline, and escaped markup roundtrip.

`tools/acceptance/cases/i010.py` remains the selected official adapter and still reports `fullTaskComplete=false`. `tools/acceptance/run_task.py` I-010/104/87 routing is not changed.

## Consequences

I-010 stays partial because source-interval crop and MP4/preview burn-in stay closed, deterministic shaping and lossless arbitrary ASS effects are not claimed, and hard dependency I-005 stays partial. No new persistence table. No production algebra, insertion order, `IMPLICIT_GAP`, or InversePatch `kind` change.

## Evidence

`docs/implementation/evidence/caption-official-sidecar-acceptance/`.
