I-023 / s4 recording-drift and confirmed-sync admission (Increment 2.85)
lives in `packages/studio_drift_probe` as `RecordingDriftAdmission`.

This directory does not host a waveform correlator, tracker, or
time-stretch engine. `run_probe.py` is not opened. Increment 2.80
media retention, Increment 2.84 VFR audio-duration admission, and
Increment 2.83 varispeed-and-pitch policy are not rewritten. I-023
stays partial: 20ms A/V, underrun, and device-switch leftovers stay
unclaimed. A 1-frame or 50ms sync measurement is not claimed.
