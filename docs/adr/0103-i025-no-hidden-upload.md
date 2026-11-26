# ADR 0103 — Official I-025 local import, archive, and export issue no hidden upload

## Status

Accepted for Increment 1.96 as a bounded slice of the original I-025 remainingAcceptance item “无隐藏上传”. Official admitted local import, explicit save, archive pack, and MP4 export stay on the local filesystem and do not issue HTTP. I-025 remains partial. `fullTaskComplete` stays false.

## Decision

Increment 1.96 first surveyed I-022 remainingAcceptance at already-admitted bounds, then I-024, then officialized exactly one genuinely not-already-official I-025 clause. No I-022 or I-024 wording is officialized in this increment, and those files are not rewritten or re-qualified.

I-022 remainingAcceptance is left listed in full:

- “同revision预览/编码前取样在V-003容差内” is already official in `opacity_render_test.dart` (exact `orderedEquals` of same-revision `previewTimelineAt` rgba versus `exportVideo(..., captureFrames:)` `preEncoderSamples` at stage `actual-yuv420-before-encoder`) and the analogous transform, dissolve, raster, and opacity-keyframe render suites, including Increment 1.18 encoder-input equality and CPU reference patches within the V-003 ≤2/255 bound. Those files are not rewritten.
- “100次取消无frame泄漏” is already official in `native/studio_media/tests/abi_test.cpp` (100-cycle opacity, transform, dissolve, and raster cancel modes leave `sm_live_owned_frames()` at the initial count and the FD delta at 0) and ADR 0022. `abi_test.cpp` is not rewritten.
- “free仅在GPU/encoder消费后” is not officializable at the GPU / FrameLease half without invention. Production has CPU RAII (`owned_frame_alloc` / `make_writable` / `avcodec_send_frame` then `owned_frame_free`), but there is no `native/studio_media/render_graph/`, no FrameLease type, and ADR 0022 plus the I-022 implementedScope already record that GPU / full FrameLease / a complete V-003 matrix is not qualified. A new RenderGraph, GPU or VAAPI port, screenshot-preview-export path, or cache/texture architecture is not invented.

I-024 remainingAcceptance is left listed in full:

- “revision固定不被编辑中途改” is already official in `audio_export_test.dart` and `local_video_test.dart` (a mid-export edit advances the live head while the export receipt keeps the frozen revision). Those files are not rewritten.
- “失败/取消无损坏成片伪成功” is already official in the same two suites (`cancelExport` preserves an existing target and leaves no `.pending` leftovers). Those files are not rewritten.
- “时长误差≤1帧、音画≤20ms、无黑/丢帧异常” is already official at the admitted offline mux bound: `tools/acceptance/run_audio_qualification.py` qualifies a 60s duration, monotonic DTS, and packet-duration check, and the I-024 implementedScope already records the Actual60s sync/DTS/pattern test; short admitted exports in `local_video_test.dart` / `audio_export_test.dart` already assert exact frame and AAC sample counts. Those files and the 60s qualification tool are not rewritten or re-qualified.

I-025 remainingAcceptance “60秒6clip工程：手改字幕/trim/撤销/保存重开后等值；恢复最后durable编辑；导出通过I-024；无隐藏上传” was then surveyed. A 60s 6-clip caption/trim/undo/save-reopen matrix is not officialized: `exportVideo` still refuses captions as `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`, and inventing a 60s 6-clip / caption-burn path is out of bounds. “恢复最后durable编辑” and “导出通过I-024” already have admitted reopen / local-export suites and are left listed, not re-qualified. “无隐藏上传” is not already official: `local_video_test.dart` and `local_video_ui_test.dart` write a local archive and MP4, but they never plant a trap HTTP server or assert that import, save, archive, and export issue zero requests. Those files are not reused, weakened, or rewritten.

The already-admitted bound implements the chosen clause: `importVideo` consumes a user-selected local file, `saveManaged` writes the explicit-save checkpoint locally, `saveArchive` packs a local archive, and `exportVideo` writes a local MP4 through the existing native encoder. No upload API is invented, and no HTTP is issued on those paths.

This increment adds:

- `packages/studio_sdk/test/i025_no_hidden_upload_test.dart`: a loopback trap server records zero requests while a granted local video is imported and `exportVideo` publishes a 90-frame local MP4; a second test records zero requests while `saveManaged` and `saveArchive` write a local explicit-save receipt and archive.
- `packages/studio_editor_ui/test/i025_no_hidden_upload_ui_test.dart`: the already-admitted `locate()` helper drives FoundationApp import, archive, and export controls against the same trap server; the local archive and MP4 are published and the server still records zero requests. `foundation_app_test.dart` is not rewritten and is not part of the official UI set.

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra and the frozen native library are unchanged; a genuine in-scope hidden upload would have been fixed narrowly and reported, and none was found. A 60s 6-clip project, caption burn-in, a full RenderGraph, I-016/I-017/I-018 platform ports, a full I-019 VAAPI port, and unfinished I-027 session/branch/HTTP-replay mapping are not invented.

## Consequences

The I-025 remainingAcceptance item “无隐藏上传” is cleared at this already-admitted local import / archive / export bound. This is not a complete I-025: “60秒6clip工程：手改字幕/trim/撤销/保存重开后等值”, “恢复最后durable编辑”, and “导出通过I-024” remain listed rather than being silently reduced. I-022 and I-024 remainingAcceptance stay listed in full and are not re-qualified.

I-021 leftover remainingAcceptance stays listed in full and is not re-qualified (`source_preview_test.dart` and `frame_proxy_test.dart` are not rewritten). I-015 leftover remainingAcceptance stays listed in full and is not re-qualified (`abi_test.cpp` is not rewritten). I-014 leftover remainingAcceptance stays listed in full: “恢复不倒退事件” still cannot be officialized without invention (same-project RestoreService / `restoreVersion` remains unfinished). I-013 leftover remainingAcceptance stays listed in full: “运行job归档固定rev并报告pending” and “不可打包资源显式manifest” still cannot be officialized without invention; the already-official I-013 leftovers are not re-qualified. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i025-no-hidden-upload/`.
