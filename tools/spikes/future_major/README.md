I-014 / s5d future-major admission (Increment 3.16) lives in
`packages/studio_future_major_probe` as `FutureMajorAdmission`.

A future major schema may be scanned only at the recognizable outer
layer. The unknown core is read-only metadata, the original package
is kept, and the core must not be interpreted or executed. This is
not a re-qualification of “不支持feature只读保留”.

This directory does not host an I-014 RestoreService or a schema
migrator. `run_probe.py` and `run_qualification.py` are not opened.
Increment 3.15 IdentityCollisionAdmission, Increment 2.51 restore
event-seq, and already-official I-014 conclusions are not rewritten.
I-014 stays partial. ID remapping is not officialized here.
