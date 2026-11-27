# ADR 0148 — Official V-007 web demux/mux lockfile candidates and feature matrix

## Status

Accepted for Increment 2.49 as the first V-007 slice. V-007 moves from planned to partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. This increment does not claim a 60s WebCodecs/OPFS roundtrip, does not pin a production lock, does not vendor or download JS packages, and does not import native FFmpeg as a fake general Web path. ffmpeg.wasm is not the default. I-037 and I-038 stay partial and are not marked complete. Quote/apply, paid generation, and SQL `vertical.v1` are not started.

## Decision

V-007 scope is “含两候选库API/版本/许可事实与WebCodecs；不导入native FFmpeg假通用.” The work-item deliverable is a WebLibraryADR, lockfile candidates, and a feature matrix. Acceptance also includes Chrome/Edge 60s samples, which this increment does not claim. s6 says WebCodecs does not define a mandatory codec and does not own the container; JS demux/mux library version and license still need a directed audit before a production lock; ffmpeg.wasm is not the default substitute. s6a first-batch Web targets are desktop Chrome/Edge; Safari/Firefox open only verified features. s13 still reserves the final library lock and runtime license audit as unfinished design-plus-measurement work.

Public npm facts observed on 2026-11-28 (Asia/Shanghai) are recorded as lockfile *candidates*, not production pins:

- `mp4box` 2.6.0, BSD-3-Clause, role=demux. API facts: `MP4Box.createFile`, `onReady`, `appendBuffer`, `setExtractionOptions`, `onSamples`, `seek`. Source: https://www.npmjs.com/package/mp4box (updated 2026-11-20). Samples are fed to WebCodecs by the host; the library does not replace `isConfigSupported`.
- `mediabunny` 1.66.5, MPL-2.0, role=demuxAndMux. API facts: `Input`, `BlobSource`, `Output`, `Mp4OutputFormat`, `BufferTarget`. Source: https://www.npmjs.com/package/mediabunny (updated 2026-11-26). MPL-2.0 is weak copyleft: distributing modified library source requires publishing those modifications. WebCodecs encode/decode still require `isConfigSupported`.
- `mp4-muxer` 5.2.2 (MIT) is deprecated since 2025-07 in favor of mediabunny and is not a candidate.

This increment officializes that bound in `packages/studio_web_media/lib/web_library.dart`:

- `WebLibraryCompiler.catalog` exposes exactly those two candidates and a feature matrix in which Chrome/Edge are first-batch targets but remain unqualified, and Safari/Firefox features stay closed.
- `WebLibraryCompiler.admit` may name a candidate on a first-batch target after codec and durable-storage checks, but `roundtripQualified` and `productionPinned` stay false and the compile does not submit or download a package.
- `ffmpeg.wasm` is `FFMPEG_WASM_NOT_DEFAULT`. Native FFmpeg as a general Web path is `NATIVE_FFMPEG_NOT_WEB_DEFAULT`. An unsupported codec is `CODEC_UNSUPPORTED`. Missing persist grant or eviction is `WEB_STORAGE_NOT_DURABLE`. Safari/Firefox are `BROWSER_FEATURE_UNVERIFIED`.

The Increment 2.37 I-020 suite (3) was re-run, not rewritten.

## Consequences

V-007 is partial. Remaining acceptance keeps the Chrome/Edge 60s sample clause. A production lock, runtime license audit, JS library integration, and browser matrix qualification remain unopened. 87-task counts become 0 complete / 42 partial / 32 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v007-web-library-candidates/`.

## Follow-up

Do not claim a 60s WebCodecs/OPFS roundtrip until that V-007 acceptance is actually measured. Do not pin a production lock without a runtime audit. Do not default to ffmpeg.wasm or import native FFmpeg as a fake general Web path. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037 or I-038 complete. Do not start signed-pack import or claim production FTS/RAG. Do not start I-039 unless a narrowly specified leftover bound is already written.
