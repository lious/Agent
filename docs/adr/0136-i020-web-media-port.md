# ADR 0136 — Official I-020 WebMediaPort codec refusal and OPFS eviction recovery hint

## Status

Accepted for Increment 2.37 as the first I-020 slice. I-020 moves from planned to partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. This is a DEV-PURE VM protocol fake in the new package `packages/studio_web_media`. It does not claim a 60s browser roundtrip, V-007, native golden command semantics, a real OPFS origin, ffmpeg.wasm, or a native hardware AVFrame. `apps/studio_web` / `BrowserProjectStore` is not rewritten. Workspace SQLite w5 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`.

Increment 2.37 first surveyed leftover I-025 remainingAcceptance (“恢复最后durable编辑；导出通过I-024”). ADR 0104 already records that those clauses have admitted reopen / local-export suites and are not re-qualified. There was no unfinished already-admitted bound left to officialize without inventing a 60s caption-burn export or rewriting those frozen suites, so I-025 was left listed and was not the increment.

## Decision

I-020 acceptance is “60秒roundtrip时长≤1帧误差；未支持codec不提交；OPFS驱逐可恢复提示；同工程与原生金样命令语义一致.” The work item profile is WEB with a V-007-qualified browser, and s6 says WebCodecs defines no mandatory codec: `VideoEncoder` / `AudioEncoder.isConfigSupported` must be checked before a real encode, `VideoFrame` / `AudioData` must be closed, ffmpeg.wasm is not the default path, and native hardware AVFrame is not reused. s5c says that when persistent storage is not granted or may be evicted the product shows “浏览器可能回收本机数据，请导出工程包”, and that canceling a file picker is not a save.

This increment officializes only the two protocol clauses at that already-specified bound:

- `WebMediaPort.isConfigSupported` / `commit` — a codec the `WebCodecHost` does not support is `CODEC_UNSUPPORTED` and leaves `commits` empty. Input buffers are closed even on refusal (live buffer count returns to 0). An `useFfmpegWasm` request is `FFMPEG_WASM_NOT_DEFAULT` and also does not commit. A supported config may commit only after `isConfigSupported`.
- `FakeOpfsStorage.probe` / `saveProject` / `pickExport` — missing persist grant or eviction returns the official hint, is recoverable, and is not a silent durable write (`WEB_STORAGE_NOT_DURABLE`, `saves` stays 0). A canceled file picker returns `saved=false` and is not a save.

A 60s timing roundtrip and “同工程与原生金样命令语义一致” are not claimed. Real browser WebCodecs / OPFS and V-007 remain unopened. This package does not import `dart:ffi` or a native media engine.

This increment adds:

- `packages/studio_web_media/lib/web_media_port.dart`
- `packages/studio_web_media/test/web/roundtrip/i020_web_media_port_test.dart` (3)
- workspace membership for `packages/studio_web_media`

## Consequences

I-020 is partial. The leftover remainingAcceptance is “60秒roundtrip时长≤1帧误差；同工程与原生金样命令语义一致。” Those clauses stay listed. 87-task counts become 0 complete / 39 partial / 35 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i020-web-media-port/`.

## Follow-up

Do not claim a 60s WebCodecs / OPFS roundtrip without V-007. Do not default to ffmpeg.wasm or load a native AVFrame. Next honest Linux/Web increment: another still-doable planned or remaining-partial slice from the four planning documents, such as leftover I-037 “未注册技法显式拒” if that SkillPackage bound is already specified. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not invent a TrimPlanner, open video muted/solo, invent PatchGroup cherry-pick or a chat workbench UI, or merge workspace SQLite w5. Do not re-qualify I-025 or I-012 leftovers already closed by ADR 0104 / ADR 0098.
