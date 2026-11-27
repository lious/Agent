I-022 / s4 preview-export consistency admission (Increment 2.92) lives
in `packages/studio_preview_export_probe` as
`PreviewExportConsistencyAdmission`.

This directory does not host a renderer, muxer, or FrameLease.
`run_probe.py` and `run_qualification.py` are not opened.
RenderRecipeAdmission, IccFirstAdmission, RotationOnceAdmission,
ColorPipelineAdmission, and the ADR 0023/0024 CPU consumers are not
rewritten. A V-003 measurement is not claimed. I-022 stays partial.
