# Increment 2.22 — 12D workbench visual language constraints

Official suite: 8 tests in packages/studio_editor_ui/test/workbench/visual_language/i025_workbench_visual_language_test.dart. Analyzer exit 0.

This officializes the workbench visual-language constraint contract from 12D and the art-design plan: layout hierarchy, 48 logical-pixel touch targets, WCAG AA 4.5:1 contrast, 200% type scale with confirm/cancel still hittable, errors not by color alone, reduced motion stopping autoplay/flicker but not program keyframes, phase-only progress, and no focus steal from a late result.

It is not a UI token or component API, not I-055, not a FoundationApp rewrite, not a real-device screen-reader pass, and not V-003. I-025 remaining acceptance is unchanged.
