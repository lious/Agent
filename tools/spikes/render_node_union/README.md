I-022 / s4 RenderNode closed-union admission (Increment 2.97) lives in
`packages/studio_render_node_probe` as `RenderNodeGraphAdmission`.

RenderNode is a closed union. Node outputs are required. The graph is
acyclic. Node fingerprints participate in the cache key, which must
not be only the source filename.

This directory does not host a renderer, FrameLease, or LUT runtime.
`run_probe.py` and `run_qualification.py` are not opened.
RenderRecipeAdmission, PreviewExportConsistencyAdmission, and
StillImageClipAdmission are not rewritten. A V-003 measurement is not
claimed. I-022 stays partial.
