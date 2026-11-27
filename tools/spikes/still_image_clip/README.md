I-008 / s4 still-image clip admission (Increment 2.96) lives in
`packages/studio_still_image_clip_probe` as `StillImageClipAdmission`.

An imageDocument or image Asset clip has `streamId=null`, a
synthesized `[0, Clip.duration)` static sampling domain, and linear
1x. Video availableRange rules must not refuse a still.

This directory does not host a renderer or video generator.
`run_probe.py` and `run_qualification.py` are not opened. ADR 0108
Ken Burns transform keyframes and I-026 leftovers are not rewritten.
I-008 stays partial.
