I-026 / s4 ImageDocument shared-effect-path admission (Increment 3.01)
lives in `packages/studio_image_document_graph_probe` as
`ImageDocumentGraphAdmission`.

ImageDocument becomes a RenderGraph node through the same color, font,
mask, and EffectRegistry as video. Allowed roles are a static clip, an
I2V first frame, or a product overlay. A separate image-only effect
system is refused.

This directory does not host an I2V runtime or an unregistered plugin.
`run_probe.py` and `run_qualification.py` are not opened. Still-image
admissions, RenderNodeGraphAdmission, GeneratedOutputAdmission, and
I-026 template / graphics-library suites are not rewritten. I-026
stays partial.
