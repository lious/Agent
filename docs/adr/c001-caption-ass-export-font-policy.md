# ADR C.1 — ASS sidecar export with an explicit font/layout policy

## Status

Accepted for Increment C.1 as a bounded slice of the original I-010 remaining work on supported SRT/VTT/ASS subset, style/font fallback, and acceptance (s3 / s8r / s12d). I-005 and I-010 remain partial. This increment does not claim I-010 complete, does not claim deterministic font shaping, and does not claim lossless roundtrip of arbitrary ASS effects. Already-delivered plain caption domain, split/trim/exact positive-rate map, manual ownership, overlap rejection, bounded SRT/VTT/static ASS import, SRT/VTT export, cue versions/undo/reopen/archive/fork, clipLocal default, explicit source anchors, caption-aware editor commands, and field-aware invert semantics stay unchanged. Official InversePatch `kind` stays `restoreSnapshot`. This slice does not change production algebra, insertion order, or `IMPLICIT_GAP`. Source-interval crop and MP4/preview text burn-in stay closed. `encode` without a font/layout policy remains `ASS_EXPORT_FONT_POLICY_REQUIRED`.

## Context

ADR 0004 already admitted UTF-8 SRT/VTT export and static ASS text/centisecond import with loss warnings, and refused ASS export until a font/layout policy existed. Full deterministic font fallback/shaping was unfinished. The remaining I-010 acceptance still required emoji/RTL/newline/non-frame-time roundtrip, unsupported-style warnings, re-ASR not overwriting hand-edited cues, a determined overlap policy, and honest font substitution: a missing requested family must be listed with its substitute and may change layout, and must never be written as if it were the original font.

## Decision

Officially admit ASS sidecar export when an explicit `AssFontLayoutPolicy` names the requested family, an ordered fallback list, a registered available-family set, and PlayRes/layout values. The written Style `Fontname` is only a family that is present in that registered set. If the requested family is missing, the first available fallback is written, warnings include `ASS_FONT_SUBSTITUTED:requested->used` and `ASS_LAYOUT_MAY_CHANGE`, and a Script Info comment records the same fact. If no registered substitute exists, export is `ASS_FONT_UNAVAILABLE`. Available names are a DEV registry of licensed/test family names, not a claim that glyph files were embedded, shaped, or redistributed. Static text, commas, literal braces/backslashes, newlines, and exact centisecond (not frame-quantized) times roundtrip in this subset; overrides and unsupported styles continue to warn or drop rather than execute. Import may use the same policy to list a substitute for a Style font without claiming that font was rendered (`ASS_STYLE_FONT_NOT_RENDERED` remains). Re-ASR continues to go through `SetCaptions(automatic: true)` and still refuses `MANUAL_FIELD_LOCKED` on hand-edited cues. Overlap policy stays a deterministic reject of intersecting half-open ranges. Captions are not burned into preview or MP4; those paths stay `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`.

## Consequences

I-010 stays partial because I-005 is still a hard dependency, source-interval crop stays closed, MP4/preview burn-in stays refused, and this slice does not finish a shaping renderer or arbitrary ASS effect roundtrip. SRT/VTT export without a font policy is unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-ass-export/`.
