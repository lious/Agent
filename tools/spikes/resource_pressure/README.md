V-023 pressure and interrupt admission slice (Increment 2.81) lives
in `packages/studio_pressure_probe` as `PressureAdmission`.

This directory does not host a measured 20-minute OOM/deadlock
probe or a real GPU worker. `run_probe.py` is not opened. I-042
pack leases and the Increment 2.77 ResourceAdmissionController
slice are not rewritten. CompatibilityStore / ModelLease are not
started. V-023 stays partial.
