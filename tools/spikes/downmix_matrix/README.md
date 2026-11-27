I-023 / s4 explicit-downmix-matrix admission (Increment 2.93) lives in
`packages/studio_downmix_probe` as `DownmixAdmission`.

This directory does not host a channel-mixer, limiter, or I-007 PCM
remapper. `run_probe.py` and `run_qualification.py` are not opened.
I-009 mix, Increment 2.83 varispeed-and-pitch, and Increment 2.85
recording-drift are not rewritten. A 20ms A/V achievement and a
resolved underrun are not claimed. I-023 stays partial. V-024 and
I-060 stay closed.
