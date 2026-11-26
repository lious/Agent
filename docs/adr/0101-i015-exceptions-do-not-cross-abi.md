# ADR 0101 — Official I-015 C++ exceptions do not cross the C ABI

## Status

Accepted for Increment 1.94 as a bounded slice of the original I-015 remainingAcceptance item “异常不穿C ABI”. Official admitted `NativeMedia` FFI turns a C++ `Error` into a typed `StudioException`; the same handle remains usable for a later legal probe; close reports `NATIVE_ENGINE_CLOSED` rather than unwinding across the FFI boundary. I-015 remains partial. `fullTaskComplete` stays false.

## Decision

Spec s7 states that C++ exceptions must not cross the C ABI. The already-admitted native library implements that bound with the `boundary()` wrapper: every `sm_probe` / `sm_export` / related string-returning entry catches `std::exception` and unknown exceptions and returns JSON `{ok:false, code}` (unknown exceptions become `NATIVE_EXCEPTION`). Dart `NativeMedia._consume` raises `StudioException` with that code and always `sm_string_free`s the returned buffer. Existing `native/studio_media/tests/abi_test.cpp` officializes 100 create/close cycles with fd delta 0 and refusal of `https://`, `file:/etc/passwd`, and relative paths as `LOCAL_FILE_REQUIRED`, but it does not officialize this I-015 “异常不穿C ABI” wording, and it is not reused, weakened, or rewritten. The loaded-Flutter `timeline_video_test.dart` already shows missing-file `probe` / `probeAsync` becoming `LOCAL_FILE_REQUIRED` and is not rewritten.

This increment adds:

- `packages/studio_media/test/i015_exceptions_do_not_cross_abi_test.dart`: a missing local file is refused as `LOCAL_FILE_REQUIRED` on the same `NativeMedia` handle for both synchronous `probe` and `probeAsync`; a subsequent legal probe of the admitted local-video fixture still succeeds; after `close` the handle reports `NATIVE_ENGINE_CLOSED`.
- `packages/studio_sdk/test/i015_exceptions_do_not_cross_abi_test.dart`: after the same typed error and close, a newly opened engine in the same isolate can still probe the admitted fixture.

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra and the frozen native library are unchanged; a genuine in-scope exception leak across the C ABI would have been fixed narrowly and reported, and none was found. New ABI surfaces, FFmpegKit old binaries, paid APIs, and a same-project RestoreService are not invented.

## Consequences

The I-015 remainingAcceptance item “异常不穿C ABI” is cleared at this already-admitted NativeMedia FFI bound. This is not a complete I-015: “borrow/retain/release配对” is already covered by `sm_string_free` on every official native response and by `sm_live_owned_frames` delta 0 in the 100-cycle cancel suites, and is not re-qualified. “100次开关0活句柄” is already official in `abi_test.cpp` `handles` (100 create/close, fd delta 0) and is not re-qualified. “越权路径/网络读取=0” is already official in `abi_test.cpp` `errors` (`https://example.invalid/media.mp4`, `file:/etc/passwd`, `relative.mp4` → `LOCAL_FILE_REQUIRED`) and is not re-qualified. Those three remain listed rather than being silently reduced.

I-014 leftover remainingAcceptance stays listed in full. “恢复不倒退事件” still cannot be officialized without invention (same-project RestoreService / `restoreVersion` remains unfinished). “zip slip/炸弹/符号链接均拒”, “fork新projectId”, “迁移中断保好副本”, and “不支持feature只读保留” are already official and are not re-qualified. I-013 leftover remainingAcceptance stays listed in full: “运行job归档固定rev并报告pending” and “不可打包资源显式manifest” still cannot be officialized without invention; “取消无半包发布” and “保留策略不删可达blob” are already official and are not re-qualified. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i015-exceptions-do-not-cross-abi/`.
