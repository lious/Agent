# ADR 0102 — Official I-021 canceled-epoch frames do not reflux into preview

## Status

Accepted for Increment 1.95 as a bounded slice of the original I-021 remainingAcceptance item “取消epoch前帧不回流预览”. Official admitted source preview refuses an in-flight `previewAssetSource` as `PREVIEW_SUPERSEDED` after `cancelSourcePreview` increments the preview epoch, and does not insert that frame into the source-preview cache. An in-flight unindexed `NativeMedia.previewAsync` is refused as `CANCELED` when `cancel()` advances the engine epoch. A later legal preview still succeeds and does not return the canceled-epoch frame. I-021 remains partial. `fullTaskComplete` stays false.

## Decision

I-021 acceptance requires that frames produced before a cancel epoch must not flow back into preview. The already-admitted bound implements that: `StudioWorkspace.cancelSourcePreview` increments `_previewEpoch` and calls `NativeMedia.cancel()`; `previewAssetSource` checks the epoch before caching or returning a frame; native `sm_preview` snapshots the engine epoch and throws `CANCELED` from `Input.check` when it changes. Existing `source_preview_test.dart` officializes 20-point indexed seeks vs sequential CFR/VFR/nonzero PTS, LRU budget/eviction, and SDK request supersession via a later `previewAssetSource`, but it does not officialize this I-021 “取消epoch前帧不回流预览” wording (it never calls `cancelSourcePreview`, and it does not assert that a canceled frame is kept out of the cache). `frame_proxy_test.dart` officializes proxy-build cancel removing a partial output, which is not preview-frame reflux. Those files are not reused, weakened, or rewritten.

This increment adds:

- `packages/studio_sdk/test/i021_canceled_epoch_preview_test.dart`: after a retained legal thumbnail is cached, `cancelSourcePreview` causes an in-flight `previewAssetSource` to fail as `PREVIEW_SUPERSEDED` without growing the cache or replacing the retained frame; a later legal preview of the canceled time succeeds, is cached, and leaves the earlier thumbnail identical.
- `packages/studio_media/test/i021_canceled_epoch_preview_test.dart`: an in-flight unindexed `previewAsync` of a late timestamp on a long local file is refused as `CANCELED` after `cancel()` advances `cancelEpoch`; a later legal preview of the admitted fixture still succeeds on the same handle.

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra and the frozen native library are unchanged; a genuine in-scope reflux of a canceled preview frame would have been fixed narrowly and reported, and none was found. Full-file decode-on-every-seek, new cache architectures, platform ports I-016/I-017/I-018, and a full I-019 VAAPI port are not invented.

## Consequences

The I-021 remainingAcceptance item “取消epoch前帧不回流预览” is cleared at this already-admitted source-preview / NativeMedia bound. This is not a complete I-021: “20点seek±1帧” is already official in `source_preview_test.dart` and `frame_proxy_test.dart` and is not re-qualified. “VFR/非零PTS不误映射” is already official in those same suites and is not re-qualified. “缓存<=预算” is already official in the source-preview LRU/budget/eviction test and is not re-qualified. Those three remain listed rather than being silently reduced.

I-015 leftover remainingAcceptance stays listed in full and is not re-qualified (`abi_test.cpp` is not rewritten). I-014 leftover remainingAcceptance stays listed in full: “恢复不倒退事件” still cannot be officialized without invention (same-project RestoreService / `restoreVersion` remains unfinished). I-013 leftover remainingAcceptance stays listed in full: “运行job归档固定rev并报告pending” and “不可打包资源显式manifest” still cannot be officialized without invention; the already-official I-013 leftovers are not re-qualified. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i021-canceled-epoch-preview/`.
