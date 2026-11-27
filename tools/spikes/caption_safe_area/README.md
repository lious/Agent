I-010 / s4 caption-safe-area admission (Increment 2.94) lives in
`packages/studio_caption_safe_area_probe` as `CaptionSafeAreaAdmission`.

`brandPolicy.safeArea` is read as normalized edge insets
`[left, top, right, bottom]`. Captions must stay inside the inner
rectangle and therefore avoid the unsafe margin bands.

This directory does not host a text shaper. `run_probe.py` and
`run_qualification.py` are not opened. I-010 sidecar and font-fallback
work are not rewritten. Source-interval crop and MP4/preview burn-in
stay closed. I-010 stays partial.
