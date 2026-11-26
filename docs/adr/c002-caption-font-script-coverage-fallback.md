# ADR C.2 — Declared script coverage fallback for ASS sidecar fonts

## Status

Accepted for captions-side Increment C.2 as a bounded tightening of the original I-010 style/font fallback work (s3 / s8r / s12d). This identifier is independent of the mainline 1.xx invert series: this branch's Increment C.1 (ASS font/layout policy; originally 1.66 on the captions clone) is already relabeled as C.1, and mainline Increment 1.66 / 1.67 remain insert-mode and includeLinks=false MoveClips invert. I-005 and I-010 remain partial. This increment does not claim I-010 complete, does not claim deterministic font shaping or bidi layout, and does not claim lossless roundtrip of arbitrary ASS effects. Already-delivered AssFontLayoutPolicy name fallback, ASS_EXPORT_FONT_POLICY_REQUIRED, ASS_FONT_UNAVAILABLE, SetCaptions(automatic: true) MANUAL_FIELD_LOCKED, CAPTION_OVERLAP, and CAPTION_RENDER_POLICY_NOT_IMPLEMENTED stay unchanged. Official InversePatch `kind` stays `restoreSnapshot`. Source-interval crop and MP4/preview text burn-in stay closed.

## Context

Increment C.1 on this branch admitted ASS sidecar export with an explicit registered family set: a missing requested family is listed with a substitute and may change layout, and is never written as the original name. A family can still be registered by name while only declaring Latin coverage, so mixed CJK, emoji, or RTL sidecar text could be written under that family as if it covered those scripts. Spec 12d asks for fixed glyph/font fallback for CJK/Korean/emoji/RTL, without this slice implementing a shaping renderer.

## Decision

When an `AssFontLayoutPolicy` includes a non-empty `scriptCoverage` map, export resolves fonts against declared script tags found in the sidecar text (a bounded Latn/Han/Hira/Kana/Hang/Arab/Hebr/Zsye subset, not a full UCD Script property). If the name-resolved family does not declare coverage of every required tag, the first listed fallback that is registered and does declare that coverage is written instead. Warnings include `ASS_FONT_COVERAGE_SUBSTITUTED:from->to:missingTags` and `ASS_LAYOUT_MAY_CHANGE`. The uncovered requested family is never written as the Style `Fontname`. If no listed registered fallback declares complete coverage, export is `ASS_FONT_COVERAGE_UNAVAILABLE` rather than silently keeping the original family. An empty coverage map keeps the previous name-only fallback and invents no coverage warnings. Import with a coverage policy lists the same substitute and still warns `ASS_STYLE_FONT_NOT_RENDERED`; it does not refuse the file. Available names remain a DEV registry, not a claim that glyph files were embedded, shaped, or redistributed.

## Consequences

I-010 stays partial. Declared coverage is optional and sidecar-only. This is not a shaping, bidi, or glyph-fallback renderer, and not MP4/preview burn-in. No new persistence table. No production algebra change.

## Evidence

`docs/implementation/evidence/caption-font-coverage-fallback/`.
