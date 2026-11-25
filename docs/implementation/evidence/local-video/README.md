# Local video evidence (2026-11-25 Asia/Shanghai)

- verification.json: final actual non-skipping suite, source hashes, commands, versions, exit codes.
- V-001.json: final clean-build/start probe (separate C ABI probe, not the media engine).
- sanitizers.log: same final native implementation, 3 CTest cases under address/undefined/leak sanitizers.
- demo-receipt.json + demo-ffprobe.json: actual persisted 320x180 H264 MP4, 45 frames / 1.5s,
  revision5 archive saved then SQLite closed/reopened and hashed equal. The binary is intentionally
  not in Git; reproduce with the maintainer command or find it under artifacts/local-video/demonstration.mp4
  in this cloud checkout. No user media was used.
- tool-versions.txt: real system compiler/build/development-package versions, installed from configured apt.
- review-failures/: historical failing test output captured BEFORE the documented fixes. These are
  deliberately retained evidence (trailing whitespace normalized; original logs remain in artifacts/), NOT current failures. The current verification.json is authoritative
  for the final scoped pass. See ../../REVIEW.md and ADR0002 for fixes and unverified original acceptance.

58 Dart/Flutter tests (56 Dart + 2 Flutter), 6 tooling unit tests, 3 native CTest cases. The 1000 seed
cases and 1000 SQLite undo cycles are inner assertions, not thousands of independent named tests.
100 dual-namespace open/close cycles (200 handles) and 10 native cancel cycles have zero fd delta.
No claim that all87 contracts, hardware/other platforms/models/paid providers have passed.
