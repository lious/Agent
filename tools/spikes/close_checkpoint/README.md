I-012 / s5b close-checkpoint admission (Increment 3.07) lives in
`packages/studio_close_checkpoint_probe` as `CloseCheckpointAdmission`.

Background, project-switch, or close must request a checkpoint
immediately and must not wait for a long generation or a ZIP. An
unfinished external package must not be claimed as written; a desktop
exit keeps the local recovery point. A mobile OS expiry may promise
only work that already has a local ACK, not an unbounded background
task.

This directory does not host a SAF or iCloud adapter, a Flutter widget
tree, or I-013 job archival. `run_probe.py` and `run_qualification.py`
are not opened. Increment 3.05 PackageAutoUpdateAdmission, Increment
3.06 ArtifactKindAdmission, ADR 0098 I-012 leftovers, and ADR 0028
gesture cancel are not rewritten. The 30s/120s s5b figures are not
claimed as a measured qualification. I-012 stays partial.
