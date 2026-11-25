# 三轮实际代码自审与修正

日期：2026-11-25（Asia/Shanghai）。均为同一实现者自审，不是独立安全审计。

## 第一轮：实际编译/静态分析/最初领域与 SQLite 测试

- 运行初始 13 项领域测试与 12 项真实 SQLite 测试通过；并发用 10 个 Dart isolate
  各发 10 个同 baseRevision 命令，1 成功/99 冲突，不是串行 mock。
- flutter analyze 实际发现 52 项 lint/弃用信息，修复单行分支、library 注释。
- 当前 Flutter 的 material.dart 已弃用，查阅官方 material_ui 包并迁移至 1.11.1。
- 根目录运行 widget 测试实际失败：Material shader 没被当前 package 打包；
  改在 studio_editor_ui package 运行，仍使用真实 SQLite，不通过 mock 掩盖问题。

## 第二轮：写入能力与可见版本

- 代码检查发现 WriterToken 原来只有 projectId/owner/epoch，若另一个 namespace
  有相同 ID/owner/epoch 可能被误用。加入 Namespace 绑定，增加对称越界测试。
- SDK 不再把“提交时最新 revision”当用户批准的 revision。UI 显式传所见版本，
  增加 stale overwrite 回归与 AppProfile 禁用能力测试。
- fixture blob 读取校验实际 bytes hash；新增故障测试。validator 增加有限 JSON
  树预检，拒绝循环/NaN，opaque extensions 不被误作有理时间解释。
- 回归曾发现两宿主测试仍使用空 features，真实抛 CAPABILITY_UNAVAILABLE；
  修正测试数据明确启用 project.metadata，而不是移除能力门禁。

## 第三轮：持久一致性、迁移失败、验收工具

- read 原先 INNER JOIN 会把丢 snapshot 的 head 当作“无工程”。改 LEFT JOIN 并
  明确 STORE_INTEGRITY，增加故障回归。
- 撤销也校验历史 before-image 的 hash/namespace/project/revision，不只校验当前 head；
  新增篡改历史快照后撤销拒绝且不写新 revision 的真实回归。
- 用原始数据库制造首次迁移表名冲突，验证 DDL/checksum/user_version 整体回滚，
  原表和数据保留；已有迁移 checksum 篡改、未知版本、事务中 outbox trigger 故障
  都有实际 SQLite 回归。
- 修正 CI 官方 archive URL 与 metadata base_url 一致；SDK 安装有 sha256 校验。
  GitHub 因缺 workflow scope 拒绝活动工作流上传；未提权，改为仅交付不执行的 CI 配方。
  C ABI 加 Int64 极值往返，避免仅检查入参接受就误称没有精度损失。
- runner 超时变为失败证据而不是丢失报告；未知任务实际退出 2；schema 三份一致性
  和测试计数过滤由 4 项实际 Python 工具测试验证。
- 加入完整空工程 golden，测试保存 JSON 与 Dart roundtrip 一致。
- 最终复跑结果以 evidence JSON 为准；源码格式、静态分析、secret/二进制和 diff
  检查在提交前执行。所有整任务保留 partial，不用文件存在或合成设计测试标 done。

## 本地视频后续批次：三轮实际审查 / 修正（2026-11-25，Asia/Shanghai）

1. **真实链路审查**：首次 native 导出失败 `COLOR_POLICY_REQUIRED`。ffprobe 确认
   synthetic testsrc 的 frame 元数据覆盖 CLI encoder 色彩选项，primaries/transfer 未指定。
   用 setparams 明确设置合成 fixture；没有放宽未知色彩准入。随后真实导入→编辑→归档→
   重开→FFmpeg 导出→跨 namespace fork 再导出通过，两个 45 帧结果逐字节一致。
2. **领域与事务审查**：发现 lift/normal 尾 trim 会静默缩短 sequence。修为保留显式尾 Gap，
   ripple 才改总长；零 delta 仍检查目标/锁/edge。历史 undo 后从最大曾用版本分配，而不是
   恢复 pin +1。1000 seeded slip/inverse 范围用例、1000 次真实 SQLite edit/undo、
   100 个竞争命令、post-definition/blob-pin 触发器失败回滚、v1→v2 重开均执行。
   v1 fixture 最初多了 Dart 三引号会忽略的首个换行，真实迁移测试发现并修正；新增防回归。
3. **边界/失败审查**：ZIP 中央目录原始重复/路径/尺寸预检、解码名称集合等值、完整 checksums
   和 manifest closed fields；错误 hash relink、symlink、损坏 CAS、超限导入拒绝。
   首次 hostile ZIP 测试的 encoder 自动规范化反斜杠，修为直接构造原始头部再验证，未降低断言。
   Native 补充逐 packet 取消、EOF 覆盖边界、重复 JSON key/depth 限制和真实 profile/alpha。
   SDK 拒绝覆盖 managed 原件/数据库；验证取消保好成片、导出中续编不改变冻结 revision。
   CTest 100 双 namespace 开关轮次与 10 次真实 native cancel 均零 fd 增量；ASan/UBSan/LSan
   重跑。共享 Flutter widget 实际点击 import/split/trim/undo/save/fork/export，不以文件存在
   或旧 schema 模拟当 App 验收。

最终命令、版本、退出码、非跳过测试计数见 evidence/local-video/verification.json；
全平台/全模型未运行范围和 TOCTOU/流式/完整撤销栈等已知缺口见 ADR 0002，不声称全部87项完成。

### 提交后连续时间戳复核（同一批次）

复核发现 native 曾在 stream 起点未知时 fallback 0、时长未知时 fallback 容器时长；
这可能隐瞒未验证的起点语义。改为明确拒绝未知流时间戳及首帧/stream 起点不一致。
额外真实 remux 一个 +7秒非零起点 fixture，经相同导入/剪辑/导出后与零起点成片逐字节一致。
这仅验证一个非零PTS组合，不升级为20点seek、VFR或CPU/GPU golden资格通过。

## Continuation — actual managed save/checkpoint batch (2026-11-25, Asia/Shanghai)

Three executed audit/fix rounds; these are self-reviews, not an independent signoff.

1. **Transaction/authority audit:** read original s5b/s5c and task contracts; replace
   archive-as-autosave assumption with immutable managed checkpoints and derived
   receipt views; add checksum migration v3 and real virtual-clock tests. Actual
   old SQLite suite: 28 tests passed (including v1→v3, rollback and edit/undo).
   Initial new suite caught an invalid test owner ID containing a space; corrected
   the fixture, not weakened production ID validation.
2. **Concurrency/publication audit:** actual save tests exposed that completing a
   receipt Future before releasing locks left immediate close reporting SAVE_IN_PROGRESS.
   Move ACK completion after cleanup. fcntl process-scoped locks alone cannot serialize
   same-process coordinators: add target FIFO. Extend the same serialization/locking
   to explicit reconciliation, recheck fence/hash and reject stale target revisions.
   Add real receipt INSERT failure after file publication, regrant/reopen reconciliation,
   external write conflict, cancellation, continued-edit and dual-coordinator tests.
3. **Replay/failure/UI audit:** committed operation replay previously accepted an
   arbitrary hash; now compare immutable receipt and reject mismatches. Add corrupt
   only-copy target, corrupt backup, injected post-stage failure, queue retry and
   cleanup tests. Remove session-only UI saved revision; actual Flutter tests check
   receipt state, lifecycle checkpoint, explicit local save and reopen. Declare the
   direct SQLite test dependency, fix all static-analysis findings. Fifty real child
   SIGKILL trials verify committed head and old/new validated output at five phases;
   no fabricated ENOSPC/platform/power-loss qualification.

Evidence and remaining original acceptance: `evidence/save-checkpoints/`, ADR0003
and the unchanged 87-task overlay. Baseline historical evidence is preserved.

Final whole-suite execution caught two additional real widget failures before commit:
invalid test lifecycle transitions (fixed to inactive→hidden→paused and back), and
a save queue Future captured in the constructor's fake-clock zone that stalled real
IO callbacks. Initialize the queue lazily in the first request's zone; rerun the
actual native Flutter path, now 2/2 passing. The first full gate failed (74 tests
executed), was not reported as a pass; final evidence is a fresh rerun.

## Caption/audio + new Web/same-session scope — three executed audit/fix rounds

1. **Domain/history:** run real Unicode/RTL/millisecond/ASS-loss goldens and SQLite
   caption CAS/manual-lock/undo/reopen. Preserve empty-caption historical sequence
   hashes; register cue versions. Fixed a nullable conditional-map cascade caught by
   analyzer. Source and timeline rationals remain exact. Refuse unsupported MP4 cue
   rendering and video ripple rather than silently drop text. Audio audit copied PCM
   into immutable buffers, rejected active unrouted inputs, bounded bus/scratch sizes,
   and tested finite overflow, mute/solo, pan/balance and protected duck layers.
2. **Actual hosts/platform boundary:** real native widget test caught single-line
   TextField silently stripping cue newlines; use multiline caption input. Rich
   unsupported captions render read-only instead of crashing/loss. Caption-before-video
   integration exposed potential non-frame filler: append at video-track end and keep
   sequence duration as max(caption/video). Browser compilation initially failed on
   a cross-package test-relative fixture path and BigInt ++; use a package-resolvable
   shared synthetic fixture and explicit BigInt.one. Actual Chrome verified >2^53
   revisions, competing IndexedDB connections, persisted reopen and editable Flutter.
   Added namespace/hash checks and transaction-complete ACK, not per-request success.
3. **Scheduler/receipt failure audit:** consume original closed PlanGraph shape, reject
   unsupported/paid side effects, encode exact versioned lease fences, and use actual
   CPU child processes with real monotonic elapsed time (not a fake process duration).
   Fixed repeated cancel incrementing its fence, terminal-replay field checks and
   unsafe boot takeover/wall-budget reset. Add persisted monotonic high-water mark.
   Actual SQL tests caught its missing eighth bind argument; fixed and reran. Inject
   a real SQLite outbox trigger failure to prove terminal-state/outbox rollback, then
   successful retry. No transport mock is presented as real encrypted networking;
   all pairing/permission/device-epoch/cost/network/physical-device gaps remain explicit.

Final source-matched native/browser gates and native clean release starts are stored
in `evidence/caption-audio-harness/`. Earlier failed runs were repaired, not counted as
passes. All original 87 tasks keep their original acceptance text; new XD tasks are
separate and no full-task completion is claimed.

The final high-water-mark edit initially also duplicated a positional heartbeat
argument; current analyzer and the six real Harness tests caught it before commit.
A targeted correction was followed by fresh full gates. Earlier failed broad/probe
reports are not used as passing evidence. Device resource reservations/parallel
heavy-work admission, trusted live device telemetry and permissions still require
the future authenticated host registry; value-object placement tests do not certify
physical hardware, signed enrollment, privacy epoch revocation or model availability.

## Native peer / approved SQLite increment — actual audit and fixes

1. Transport/API audit: initial analyzer rejected nonexistent HttpClientRequest.certificate. Replaced it with official cancellable SecureSocket/ConnectionTask factory; CA validation and exact DER pin now complete before SDK writes HTTP bytes. Real tests exercise valid/absent/unpaired identities, wrong pin, missing server CA and direct-unreachable outcomes. No certificate-bypass callback or administrative RPC was added.
2. Transaction/time/replay audit: nested SAVEPOINT rollback keeps dispatch/binding/outbox/peer receipt atomic (real SQL trigger abort, then successful retry). Trusted wall high-water is persisted separately even for rejected expired authorization; strengthened rollback test stays above original issuance time yet below observed-expired time. Duplicate revoke increments epoch only once; every cached response rechecks current authorization. Cached claims now return derived remaining time and cannot revive expired/replaced leases. Absolute stream deadlines replace resettable inactivity timers.
3. Result/resource/restart audit: closed pinned builtin result schemas and provenance/fingerprint binding reject malformed or wrong-source candidates; local-owner CAS boot takeover cannot reset wall budget or reuse old boot. Unknown elapsed time consumes remaining budget. Node attempt hard deadlines persist across reopen and cannot be stretched by heartbeats; v4 active lease migration preserves its known cutoff.
4. A further REAL failing regression found a resource bug: after a retry overwrote a node's old-device lease, a second coordinator restart lost that old device's quarantine. `evidence/peer-tls-sqlite/quarantine-audit-failure.log` contains the observed unexpected successful claim. Fixed by carrying ALL outstanding old-boot quarantine rows, not merely devices still visible in per-node step state; corrected regression and full suite rerun.

Environment failures are not passes: refreshed box lacked cmake/pkg-config/clang/development headers, then nlohmann_json. Initial full gates failed for these exact prerequisites; a temporary SQL JSON-path Dart interpolation error also failed a concurrent build and was corrected to a raw DDL string. Installed only official Debian build packages using existing passwordless box permission; no user machine or credential accessed. Re-executed the final stable-source full gates rather than reusing those failed reports. SQLite build comes from hash-verified official source in isolated toolchain path, not a changed version assertion or system-library substitution.

Not closed: physical devices; OS identity provisioning / pairing UI / browser transport; scoped resumable blobs; global/live resource attestations; full privacy/rights/paid budget ledger; original complete Schema/replan/media/audio/AAC contracts. Existing I-003 100-competing-CAS/undo/rollback/namespace tests are genuine, but do not erase its upstream complete-Schema dependency or turn library probes into App tests.

## Linux OS identity + explicit native UI + bounded blob inbox — three actual rounds

These are executed code self-audits/fixes, not an external security review.

1. **Identity/endpoint lifecycle:** inspected actual Linux Secret Service plugin behavior;
   added exact OS-store readback, stable store-wide OS-user-root SHA256 cross-process lock plus
   store-wide in-process FIFO and cleanup in nested finally. Removed any need for plaintext fallback/whole-store
   access. Certificate private key travels only stdin/process memory/OS store. Fixed bind/close
   race and ensured close cleans listener even when revoke fails. Actual isolated encrypted
   keyring + native Flutter load/reload verifies stable public identity; no user keyring read.
   Public Linux plugin source audit found an APPLICATION_ID-wide aggregate read-modify-write;
   per-namespace locks would not prevent cross-namespace lost updates, so the supported SDK now
   supplies one store-wide path and all NativeIdentity calls share one FIFO. Real SDK assertions
   check distinct identity scopes share the lock. Locked/denied backend remains unqualified.
2. **Transfer transaction/resource/replay:** every chunk uses existing certificate/scope/
   revision/epoch guard before replay. Added real SQL-trigger outbox abort + rollback/retry,
   chunk/final hashes, conflicting repeats, receiver reopen/resume and revoked-cache denial.
   Corrected repeated full-byte chunk loading (O(n²)) to index-only status, and bounded file
   preparation using immutable typed snapshots instead of unbounded/boxed reads. Review also
   caught unequal treatment of identical bytes using valid alternate Base64; normalize decoded
   bytes for comparison and exercise this over real TLS. Limits are logical reserved payload,
   not a misleading physical disk ceiling. Inbox is deliberately distinct from project CAS.
3. **Real operator/restart/migration:** actual two-pane Linux integration clicks secure-store
   identity -> both full fingerprints -> separate metadata/blob consent -> remote CPU -> exact
   file bytes -> other CPU SAME PlanGraph -> revoke -> fresh session re-pair. Fixed retained
   closed UI session handle preventing explicit re-pair; assert the new sessionId differs.
   Final SDK audit added the existing AppProfile metadata gate to compute-session creation and
   owner inbox reads, with actual denied-profile regressions; native UI also rejects a wrong
   independently confirmed fingerprint before any listener is started. The new UI negative test
   initially failed because the integration binding retained focusedEditable across native-control
   focus changes: actual controller diagnostics proved the replacement text never reached the field,
   not that a wrong fingerprint passed. Reset the public test-driver focus cache and assert exact
   field text for every entry; keep the wrong-fingerprint rejection and full end-to-end assertions.
   Retain the observed failing diagnostic, not present it as a successful security test.
   Genuine committed-v4 and committed-v5 probes initially exposed an incorrect500ms expected
   deadline in the *v5 test harness* (actual hard deadline1000ms); corrected baseline expectation,
   left production gate/migration intact, reran both real versions and old-runtime rejection.
   Resource audit also found the new local executor used a session-derived device ID, allowing
   concurrent sessions to look like different devices. Use one stable namespace/database-local
   slot and run two real overlapping CPU sessions: second claim DEVICE_RESOURCE_BUSY, release on
   first commit, then second succeeds with unchanged Project revision. Unknown crashed-slot
   recovery stays conservative and explicit; no new device-ID bypass or silent budget reset.
   Final static analysis/full native/actual Chrome/OS UI/clean release starts are rerun from
   frozen source; historical failed logs are not counted as passes.

Remaining full acceptance is unchanged: browser authenticated transport, physical devices,
other platform OS identity stores/builds, full Schema/media CAS, real audio/AAC/model/paid work,
full rights/privacy/resource attestation. This is not a claim that all87 or allXD10 are complete.
