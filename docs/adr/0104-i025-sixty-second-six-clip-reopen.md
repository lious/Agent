# ADR 0104 — Official I-025 60s 6-clip caption, trim, undo, save, and reopen document equality

## Status

Accepted for Increment 1.97 as a bounded slice of the original I-025 remainingAcceptance item “60秒6clip工程：手改字幕/trim/撤销/保存重开后等值”. Official admitted import, SplitClip, SetCaptions, TrimClip, linear undo, saveManaged, and same-database reopen keep document equality on a 60s six-clip project. I-025 remains partial. `fullTaskComplete` stays false.

## Decision

I-025 leftover remainingAcceptance after Increment 1.96 is “60秒6clip工程：手改字幕/trim/撤销/保存重开后等值；恢复最后durable编辑；导出通过I-024.” This increment officializes only the first item, at an already-admitted document-equality bound. It is not caption burn-in and not export. `exportVideo` still refuses captions as `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`; a caption-burn path, a 60s export, and new commands are not invented.

The 60s six-clip fixture is built from already-admitted APIs: the admitted local video is looped to 60s with the already-used ffmpeg `stream_loop` / `-c copy` recipe, then imported with `importVideo`, split with five `SplitClip` cuts at 10s timeline marks, hand-edited with `SetCaptions`, trimmed with admitted ripple `TrimClip`, undone with linear undo, checkpointed with `saveManaged`, and reopened from the same database. No new editor command, upload API, RenderGraph, or session surface is added.

Existing suites do not officialize this wording and are not rewritten: `local_video_test.dart` splits, trims, and reopens a 3s one-source project without six clips, hand-edited captions, or a 60s duration; `local_video_ui_test.dart` is the same 3s clicked path; `save_test.dart` officializes save receipts, not this 60s six-clip caption/trim/undo matrix; `caption_split_trim_test.dart` officializes caption follow across a 3s split/trim and is not a 60s six-clip save/reopen close. 「恢复最后durable编辑」 and 「导出通过I-024」 already have admitted reopen / local-export suites and stay listed, not re-qualified; those files are not reused, weakened, or rewritten.

This increment adds:

- `packages/studio_sdk/test/i025_sixty_second_six_clip_reopen_test.dart`: after a 60s import is split into six packed 10s clips and captions are hand-edited, a ripple out-trim is undone and `saveManaged` plus reopen equal the post-undo document (six packed clips, duration 60, edited cue text). A second test keeps the committed trim: reopen equals the trimmed six-clip document (duration 59, last clip 9s, edited cue text).
- `packages/studio_editor_ui/test/i025_sixty_second_six_clip_reopen_ui_test.dart`: the already-admitted `locate()` helper drives FoundationApp import, five 300-frame splits, caption-add / caption-edit, ripple trim, undo, and save-managed; reopen of the same database equals the post-undo document. `foundation_app_test.dart` is not rewritten and is not part of the official UI set.

Existing codes are not retargeted, including `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`. Official InversePatch kind stays `restoreSnapshot`. Production algebra and the frozen native library are unchanged; a genuine in-scope save/reopen inequality would have been fixed narrowly and reported, and none was found. I-027 session/branch/HTTP-replay mapping is not invented.

## Consequences

The I-025 remainingAcceptance item “60秒6clip工程：手改字幕/trim/撤销/保存重开后等值” is cleared at this already-admitted import / split / caption / trim / undo / saveManaged / reopen bound. This is not a complete I-025: “恢复最后durable编辑” and “导出通过I-024” remain listed rather than being silently reduced.

I-022 remainingAcceptance stays listed in full and is not re-qualified (a RenderGraph / GPU FrameLease is not invented). I-024 remainingAcceptance stays listed in full and is not re-qualified. I-021 leftover remainingAcceptance stays listed in full (`source_preview_test.dart` and `frame_proxy_test.dart` are not rewritten). I-015 leftover remainingAcceptance stays listed in full (`abi_test.cpp` is not rewritten). I-014 leftover remainingAcceptance stays listed in full: “恢复不倒退事件” still cannot be officialized without invention (same-project RestoreService / `restoreVersion` remains unfinished). I-013 leftover remainingAcceptance stays listed in full: “运行job归档固定rev并报告pending” and “不可打包资源显式manifest” still cannot be officialized without invention; already-official I-013 leftovers are not re-qualified. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Planned I-026 image layers / templates and I-020 WebMediaPort are not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i025-sixty-second-six-clip-reopen/`.
