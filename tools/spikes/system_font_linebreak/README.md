I-010 / s4 system-font line-break admission (Increment 2.95) lives in
`packages/studio_system_font_probe` as `SystemFontLineBreakAdmission`.

Caption layout must use an explicit fontRef or font hash, not a
platform system-font default that would make line breaks differ
across platforms.

This directory does not host a text shaper. `run_probe.py` and
`run_qualification.py` are not opened. I-010 sidecar and font-fallback
work, ADR 0019, C.001, C.002, and Increment 2.94 CaptionSafeAreaAdmission
are not rewritten. Source-interval crop and MP4/preview burn-in stay
closed. Deterministic shaping is not claimed. I-010 stays partial.
