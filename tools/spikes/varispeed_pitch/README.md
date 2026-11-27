I-023 / s4 first-version varispeed-and-pitch admission (Increment 2.83)
lives in `packages/studio_varispeed_probe` as `VarispeedAdmission`.

This directory does not host a time-stretch engine, I-007 PCM remapper,
or limiter. `run_probe.py` is not opened. I-007, I-009, I-024 leftovers,
Increment 2.81 V-023 PressureAdmission, and Increment 2.82 I-005 0.02s
link-offset work are not rewritten. I-023 stays partial: 20ms A/V,
underrun, and device-switch leftovers stay unclaimed.
