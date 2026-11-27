I-014 / s5d identity-collision admission (Increment 3.15) lives in
`packages/studio_identity_collision_probe` as
`IdentityCollisionAdmission`.

A same projectId+revision+hash import is a duplicate and must not
overwrite the existing project. The same projectId and revision with
a different hash is `IDENTITY_COLLISION` and must not overwrite. A
Flutter open-or-fork prompt is not invented.

This directory does not host an I-014 RestoreService or a migration
runtime. `run_probe.py` and `run_qualification.py` are not opened.
Already-official I-014 conclusions and Increment 2.51 restore
event-seq are not rewritten. I-014 stays partial. Future-major
read-only is not officialized here.
