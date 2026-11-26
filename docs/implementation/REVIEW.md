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


## v1.3 Recovery / CAS adoption / GC — three actual code-review rounds

Executed self-audits and corrections, not an independent security audit.

1. **Recovery/time/permission transaction:** inspect existing takeover contract and
   actual Linux kernel clock. Persist exact metadata/plan/owner inputs, use kernel
   CLOCK_BOOTTIME (includes suspend), reject anchor/coordinator mismatch, preserve
   attempts and budget. Unknown/reboot clocks exhaust remaining budget. Inject a real
   SQL UPDATE trigger abort: takeover/manifest/grant transaction rolls back, old
   coordinator still works, retry succeeds. Owner mismatch/revision drift fail.
   Exact recovery receipt replay leaves a new grant intact; old endpoint replay
   after recovery is denied over actual TLS. Initial test used a nonexistent
   undoLatest SDK method; analyzer rejected it, fixed to the real undo method.
2. **Publication/GC interleaving and idempotency:** keep filesystem maintenance lease
   from publication through SQL pins for every supported SDK publisher; reject public
   uncontrolled AppendVideoAsset bypass. Adoption edit and receipt share one SQL
   transaction: real INSERT-trigger abort preserves head/asset set, then retry and
   exact dedup succeed, changed-input repeat rejects. Run actual adoption overlapping
   GC and export after save/reopen; protect historical undo media. DELETE-trigger
   abort proves inbox/chunk/object rollback. Real filesystem test checks symlink
   refusal, other-namespace isolation, active staging/pins and lock cleanup on failure.
   GC never promises global FS rollback or SQLite physical disk shrink.
3. **Resource/UI/fence regression:** a REAL concurrent regression reproduced a
   fresh-session quarantine bypass after coordinator recovery: expected
   DEVICE_RESOURCE_QUARANTINED but got a successful candidate hash (retained failure
   evidence). Check all device quarantine boots; only their persisted owner clock
   can prove expiry. Carry old reservations on takeover and retire old rows. Repeat
   original takeover regression plus real owner-clock wait/release/fresh-session
   execution. Also inspect queued CAS import/adoption: before waiting for the lease
   they must capture project AND writer. Fix same-project writer ABA, and prove with
   a real held filesystem lease, same-project reopen/new fence, then queued release:
   both import and adoption reject PROJECT_CHANGED without assets/CAS publication.
   Actual isolated OS-keyring/native widget integration now closes/reopens DB/widget,
   reloads the same identity, rejects missing recovery consent, recovers SAME session,
   finishes pending local work and does not restore listener or peer permissions.
   Extended final audit reproduced another real failure: new constructor used
   session ID as boot and registration silently returned an existing plan. A repeated
   session ID could create a new-clock coordinator without explicit recovery. Keep
   that failing log; generate a fresh coordinator UUID independently of session ID,
   reject boot-mismatched registration and rerun all takeover/recovery/media cases
   plus the full frozen-source gates. Unchanged low-level same-boot idempotent
   registration remains trusted-coordinator API, not a remote authorization route.
   One final ownership-path audit then reproduced stale SDK grant/invitation success
   after takeover. All peer RPCs were already boot-fenced, but local administration
   must be fenced too: new synchronous boot-checked writer transaction wraps grant
   offer/confirmation and revoke, and stale invitation/listen/recovery registration
   fail. Old close catches only COORDINATOR_FENCED while always closing its socket;
   a real regression asserts it does not revoke a NEW current-owner grant. Retain
   both observed failing assertions, then rerun thirteen focused takeover/recovery/
   adoption tests and the full native/Chrome/OS-UI/release/migration gates.

Early successful diagnostics predate the final writer-ABA correction and are not
final-source evidence. Final native/Chrome/UI/clean release gates and genuine
v4/v5/v6->v7 migrations are rerun after freezing the apps/packages/tools tree.
System SQLite3.46.1 is still refused, not relabeled approved. No non-Linux or
physical-device result, Web transport, real audio/AAC/seek or full Schema claim.


## v1.4 WebRTC + source seek/cache — three actual self-review/fix rounds

Not an independent security audit. Failures are retained, never renamed passes.

1. **Browser identity/protocol/durable authority:** actual RTCCertificate IDB races
   and reopen, standard DTLS fingerprint pinning before SDP, no ICE servers or
   anonymous endpoint. Real Chrome produced0 host candidates; inspected only
   relevant managed WebRTC policy keys and STOPPED positive network qualification,
   without changing policy/flags or substituting a transport. Default tests were
   separated from explicit nonzero positive qualification, not silently skipped.
   Bound request frame/body IDs, reject malformed pins, wake closed readiness
   waiters; persist whole-session revoke so even unstarted local work is denied.
   Real IDB rollback/reopen/legacy migration and UI identity/consent/revoke tested.
2. **Actual media/index/cache ownership:** native container index+decoder flush,
   independent sequential pixel/PTS reference,20 exact CFR targets and real
   nonzero/VFR fixtures; reject EOF/multiple streams/HDR. Review caught decode
   dispatch after CAS await/close and stale UI images: recheck epoch/project before
   dispatch and on return, map canceled late errors to superseded, clear displayed
   image on edit/selection. Validate pixel range/dimensions BEFORE allocation;
   exercise immutable bytes/byte budget/oversize/LRU and256-entry cap.
3. **Fence/resource/timing/final UI regression:** actual browser IDB lease expiry,
   retry increasing fence, old result rejection, cross-session device reservation,
   heartbeat regression/hash failure rollback and revoke before replay. No mock
   transport is counted as network validation. Initial Flutter preview click test
   really failed pumpAndSettle while asynchronous codec/busy animation remained;
   pump real IO+frames before settling. Next run decoded a real RawImage but wrongly
   asserted off-viewport lazy status text; assert actual128x72 decoded image and
   stale-image removal after split instead. Corrected test ran import→source seek→
   split/trim/undo→archive/fork→90-frame export. Browser widget test similarly needed
   fake-time advancement for ICE timers; retained initial failure. Qualification
   outside test/ failed compiler serving; moved unchanged explicit positive suite
   under test/qualification with non-_test filename and retained compile failure.
   Final signaling audit closes after-gather close race and validates fingerprint
   type before JS; full frozen-source gates/migrations/OS UI/release starts rerun.

Current managed-policy blocker is only the POSITIVE browser direct transport
qualification. Native bridge/worker durable reconnect/media audio/proxy/full Schema
remain actual implementation gaps, not excuses or fabricated external blockers.

Final acceptance recheck: I-005 still lacks multi-select/group/snap/paste/overwrite;
I-006 lacks linked multi-track propagation; I-009 lacks full Project Effect/link
integration; I-010 lacks font/style fallback/rich anchors; I-012 lacks full exit/
draft state machine and upstream I-011 closure. They are not marked complete just
because some acceptance examples pass. Final buffer review includes the pending
encoded frame bytes in the256KiB bound, rather than checking only old bufferedAmount.

## v1.5 offline audio/AAC — three actual review/fix rounds

Not an independent codec/security audit. Failures remain failure evidence.

1. **Native sample/format/duration ownership:** first real PCM44.1k impulse test
   failed AUDIO_LAYOUT_UNSUPPORTED because ordinary WAV describes only a channel
   count. Normalize ONLY standard1/2channel layouts and explicit PCM-WAV zero
   origin; still reject surround/unknown timing. Bound rescaled timestamps before
   subtraction, validate format/PTS continuity/all decoded finite floats, drain SWR
   with actual null input, and require full coverage inside declared source bounds
   rather than silently zero-pad truncation. Keep legitimate out-of-stream silence.
   Fix single-close/cleanup ownership in the bounded Dart file pipeline. Real
   impulse output48000samples and peak24000/trimmed23000, NaN/layout/PTS/overwrite/
   duration limit failures are tested. The initial SDK test also had an undefined
   hash helper compile failure; fix the test to actual exported rawBytesHash.
2. **Revision/cancellation/edit contracts:** reject nonfinite/range-invalid master
   commands BEFORE canonical command hashing, test no-op/revision preservation,
   undo and actual store close/reopen. Introduce workspace export serialization,
   reject EXPORT_BUSY and check cancellation after CAS/probe/temp awaits BEFORE
   dispatching the next native stage. Map late close/cancel errors without false
   publication. Real export concurrent with master gain/head edits retains the
   frozen revision and -6dB content (measured RMS ratio, not just recipe equality).
   Mute produces real decoded silence; canceled SDK export preserves existing target.
3. **Actual UI/active codec/release envelope:** root-invoked widget test really
   failed missing shader assets; use the owning Flutter package as the real runner
   already does. Added controls shifted lazy-list navigation: undo and persistence
   text really became unbuilt, so scroll to keyed controls/status and KEEP original
   visible text assertions. Do not delete assertions or count test mocks as media.
   Initial active-AAC cancel test wrongly inferred progress from buffered file size
   and the export completed before cancel. A diagnostic now observes actual AAC
   submitted input;10 new cancels wait for4800 submitted samples before cancel,
   assert CANCELED/closed-handle rejection and FD delta0, retaining10 silent cancels.
   This is explicitly NOT a presented AudioSink clock. One attempted fix was skipped
   by an unrelated failed shell guard; retain that second failure and actually
   apply/rebuild/rerun. Final codec review caught that an SPS Main4 label alone
   does not constrain CRF bitrate: add actual20Mbps maxrate/25Mbit VBV CPB plus
   existing frame/MBPS gates and profile/pixfmt verification. Re-run the ENTIRE
   native/60s qualification after this correction; earlier passes are diagnostics,
   not final-source qualification.

The actual60s fixture runs the production SDK import/save/frozen export path while
editing the head. Independent ffprobe/decoded flash+audio pulse observations test
1800frames,2880000 logical samples, real AAC priming/last-packet duration and DTS.
It is Linux software OFFLINE qualification, NOT an AudioSink presentation-clock,
P0 device, other-platform or full original-task pass. Full Schema/AudioClip/link
integration, proxy/timeline playback and RenderGraph still need actual coding.
Original87 criteria/dependencies and104 snapshots are unchanged. Browser positive
WebRTC remains nonzero/blocked; no managed-policy change or alternate route.

## Increment1.6 — three actual self-review/fix rounds (not independent audit)

1. **Schema/reference/ownership audit.** Replaced recursive ID heuristics with declared entity enumeration; preserved unknown extensions/plugins rather than allocating IDs from opaque maps. Cross-checked original generic Clip/EntityRef/LinkGroup/TimeMap contracts; allowed asset subjects instead of narrowing Shot subjects to characters; preserved external font/provider/template/job identifiers. Added reciprocal effect ownership, source-version/map/retained metadata, image/story and other semantic checks, bounded repeated nesting traversal and linear image-parent cycle checks. Added a full original-Schema rich fixture plus valid roundtrip and targeted semantic failures; hardened opaque numeric version/Q handling and iterative3000-node routing validation instead of recursive stack growth. The initial fixture used an invalid plugin SemVer; real structural failure retained and fixture corrected to1.0.0. Rich app writes correctly refused; the test was corrected to assert fail-closed/no-side-effects rather than bypass that gate or claim full app support.

2. **Atomic linked edit/SQL review.** Reconciled absolute stream origins and48k boundaries; verified positive/negative source availability, link offsets, locks, collisions, duplicate extraction/IDs, unlink preservation, selected-audio split and continued append. Found a real new-unlinked-audio-right version allocation gap; fixed it and added actual undo/re-edit same-ID SQL regression. Added1000 exact linked inverse operations. Real event-trigger failure proves all-table rollback after definitions/pins, followed by exact retry/dedup/stale-CAS/undo/reopen. Corrected test API omissions and used the existing canonical REVISION_CONFLICT code rather than changing production errors.

3. **Actual user-path/export review.** Exercised real codecs and editor clicks, not only models/ports. Found that the UI's previous unconditional ripple trim would reject linked audio; implemented explicitly labelled leave-gap trim/delete in this restricted mode. The real archive/fork user path exposed stale AV group/member/anchor references in the original fork remapper; fixed all declared AV reference keys and added a direct fork regression plus actual SDK archive/fork/AAC export. Also replaced UI timestamp split IDs with the SDK's production UUIDv7 allocator. Fixed widget scroll/hit-testing using actual Scrollable.ensureVisible context after invalid test API/asset-cwd failures, retained those failed logs, and reran owning-package/full gates. Checked mutually exclusive source modes, default persisted audio, actual muted output, archive/fork/reopen and existing frozen export/cancel/atomic-output/resource/security regressions. Preserved no AudioSink/device-clock claims and did not re-run or bypass unchanged managed WebRTC failure.

## Increment1.7 — three actual playback reviews/corrections

Original acceptance is not replaced by this restricted development qualification.

1. **Clock/native ownership review.** Rejected a submitted-frame/wall-time clock and
   used real asynchronous libpulse timing without interpolation. Added explicit
   initial timing/cork deadlines and500ms stale-clock invalidation, drain
   acknowledgment, uncertain tail disclosure and paused rebind. Real producer
   SIGSTOP0.8s initially hit clock-stale before its queued underflow callback; this
   is retained failure evidence, not renamed success. A separate300ms actual
   starvation experiment exercises real underflow, and independent daemon SIGSTOP
   exercises actual clock staleness. Actual sink suspension exercises device loss.
2. **SDK/UI lifecycle/resource review.** Found that a non-playing preparation could
   finish after backgrounding and start sound. Added cancel-preparation/pause-opened
   lifecycle behavior with no autoresume, actual SDK and clicked UI tests. Moved
   all throwing recipe validation/snapshot creation before acquiring PCM fd;
   constructor invalid-type failures no longer leak descriptors. Added close/open
   fencing. Own preparation directory until isolate work ends; adopted playback
   cleanup is separate. Fixed the qualification launcher changing toolchain HOME
   (which generated ephemeral pub-cache references); only daemon HOME is private.
   Restored pinned workspace dependency resolution offline and re-analyzed.
3. **Adversarial control/path/load review.** Found FIFO open could block before the
   regular-file check: added O_NONBLOCK and actual FIFO/symlink/size/nonfinite
   refusals. Strengthened local-server grammar to reject mixed remote lists, no
   autospawn or fallback. Busy/open and invalid seek/sink operations preserve the
   active session; real repeat open/stop and malformed constructor trials leave fd
   count unchanged. Clicked UI now verifies actual background cork/no-autoresume.
   Real SDK monitor capture must contain finite nonzero audio, not just clock
   progress. The first unreserved parallel CPU/crash gate observed a **real underrun**
   and correctly froze: retained, NOT a V-004 stress pass. Positive real-time service
   cases now run mandatorily and sequentially after the broad parallel suite; no
   skips and no weakened underflow/failure assertions. Final lifecycle test lint
   was found by the real analyzer and corrected, not ignored.
   A later integrated clicked-UI play timeout is also retained (its original helper
   lacked native-state detail). Three immediate SDK→UI pairs on the same real
   service passed, so this does not establish a hardware/stress fix. Added timeout
   native-state diagnostics and explicit service-tag configuration. Re-read official
   Pulse buffer docs: request overall latency with PA_STREAM_ADJUST_LATENCY and
   publish measured latency/sign/validity, without relaxing any queue/underflow
   assertion. Normalized cancel-vs-isolate-attachment races to CANCELED and added
   actual in-flight cancellation coverage. Intermittent unreserved/load behavior
   remains a qualification limit, not silently erased by a later passing gate.

Qualification explicitly stops at a real Pulse17 software service/monitor. No human
hearing, physical DAC/latency, PipeWire/P0,20-minute thermal or presented video AV
qualification is asserted. Both Pulse-enabled and explicit-OFF native configurations
are tested on Linux; OFF is not a non-Linux build. Original87 and XD10 remain separate.
No original104 snapshot, acceptance or hard dependency was changed; no new RTC policy
attempt/bypass, production endpoint, paid call, Mac access or workflow activation.
Detailed exact runs, source hashes, failures and limits: `evidence/audio-sink/`.

## Increment1.8 — three actual review/fix rounds

1. **Native time/resource admission.** Reused the real preview conversion in bounded
   one-time original-PTS RGBA proxy generation, not FFmpeg CLI in production.
   Added monotonic original PTS/first-origin/duration checks, pre-codec2048² gate,
   exclusive0600 output, write/cancel/fsync rollback,64MiB/2048frame limits. Actual
   generated CFR/VFR/nonzero fixtures compare20 exact points each, plus malformed
   manifests, hash corruption, actual mid-output cancel and real quota rollback.
   Native decoder pixel conversion remains independently unqualified for V003 GPU
   colour patches: shared helper equivalence is not that acceptance.
2. **SDK ownership/clock review.** Fixed busy acquisition around NativeMedia.open,
   reader-vs-dispose lifetime, queued cancellation/project hash fences and per-source
   cache mapping identity (equal image bytes must not alias different PTS metadata).
   Added single in-flight read backpressure and separate playback generation because
   a new native handle can repeat epoch1. Real service tests cover frozen pause,
   exact seek, rebind, restart, linked edit invalidation, cancellation and cleanup.
   Export compiles the same admitted graph's source ranges against original files,
   retaining the pre-existing unsupported-canvas refusal precedence.
3. **Actual UI/readiness review.** FakeAsync widget video pause timed out twice;
   retained, not converted to a passing mock. Reserved the preview layout so image
   arrival cannot move controls. Moved new AV assertions to real Linux native
   IntegrationTest binding (retaining baseline audio widget regression). Its first
   actual run correctly found repeated native driver input had stayed0 instead of
   500ms; reset the driver's focusedEditable cache and assert actual input text.
   Added real moving-RGBA and paused0/500ms pixel assertions, bounded image decode
   timeout/late-image disposal, generation fences and visible skipped/late counters.
   This is software-service/native-UI evidence, not physical AV or full texture
   lifetime/100-cancel/GPU qualification. Actual failed logs remain evidence.

Original104, exact acceptance/title/scope/dependencies of all87, separateXD10,
strict approved SQLite runtime and v4-v7 migrations remain unchanged. No unchanged
positive RTC rerun/policy change/relay, production/paid/OAuth/workflow/Mac action.

   The first full gate also genuinely failed two existing source-preview widget
   paths: the busy indicator had become unbuilt below the lazy viewport, so a
   fake-time pumpAndSettle spun while real codec completion was outstanding. Moved
   the actual busy indicator to an always-built fixed overlay (no assertion
   removal) and cleared the closed preview adapter reference so widget disposal
   after workspace close is idempotent. The audio-only rebind/resume widget also
   observed a real underrun at25266 samples and correctly invalidated the clock;
   retained the entire failing gate. Added actual worker-loop maximum scheduling
   gap and negotiated target/prebuffer telemetry, NOT a wall-derived media clock,
   larger queues or relaxed fault assertions. A later positive run cannot prove
   that this unreserved-host scheduling problem is fixed or qualify V004 stress.

   Final geometry inspection caught a real portrait-gap defect: black gap pixels
   were hardcoded16:9. Gap geometry now comes from the same exact integer canvas
   scaling as native preview; portrait dimensions and disabled-gap behavior have
   a domain regression. Also made new native AV integration fullyLive so engine
   frames continue between driver operations; earlier driver-paced diagnostics
   are retained, not presented as display performance. Re-run the complete gate
   against the final production/test sources after both corrections.


   FullyLive进一步真实失败后，逐帧完整Schema解析/hash和全表单setState已移出视频热路径：
   仅复用第一次完整验证的不可变snapshot/graph，并逐帧检查namespace/head coherency。
   新增第二连接修改HEAD/跨namespace回归；不是用廉价查询取代初始完整性检查。
   独立player notifier使实际引擎帧能在driver操作之间推进；暂停稳定帧才做像素readback。
   对新帧的20ms采纳检查不是已显示图像最大年龄，明确保留best-effort hold-last-frame限制。

   Actual native abort was traced in our synthetic child (both default Impeller
   and supported Skia failed). GDB showed GNU rethrow entering Flutter's unwind
   implementation. Linux now links a PRIVATE static GNU runtime with only sm_*
   C ABI exports; final ELF symbol/NEEDED audit and actual loaded-Flutter sync +
   async missing-file exceptions are mandatory, not replaced by CLI coverage.
   No kernel/core-policy elevation; the rejected core-limit request was not retried.

   After containing exceptions, plain Pause->Resume still genuinely underflowed,
   with a full ring and worker-loop gaps under6ms in the retained run. A larger
   requested target/prebuffer also failed; reverted original requests/hard bounds.
   Resume now rebuilds from the confirmed paused SERVICE sample with a fresh
   epoch, exposing snapshot unconfirmed-tail uncertainty and awaiting a new clock.
   Duplicate active resume is idempotent. Tail uses ONE locked published status,
   not racing reads of worker counters. Extended actual-service qualification to
   plain pause/resume (previous cases mainly sought first), duplicates, real
   SIGSTOP starvation, device suspend, server stall and cleanup. This is NOT a
   proof of Pulse internals, seamless DAC resume or physical AV/performance closure.


   Final frozen-source rerun:169 native Dart/Flutter +9 Chrome +1 actual isolated
   OS-keyring UI =179 distinct,0 skips. Six actual clean release builds/starts
   (three per native host) and three independent minimal ABI probes passed.
   Actual Pulse fault/monitor/plain-resume regression,60s offline PCM/AudioBus/AAC,
   explicit Pulse-OFF CTest/proxy/refusal, and v4/v5/v6->v7 migrations passed.
   First direct fault-harness launch genuinely failed because its D-Bus name was
   already held; retained stdout/stderr, then used the existing isolation contract
   (a NEW dbus-run-session for its own synthetic server), not an owner service or
   relaxed assertion. Final verification source hashes match the checkpoint source.
   Original87 remain0 complete/25 partial/49 planned/13 blocked; XD10 separate
   0/8/1/1. No platform/hardware/P0 or physical-device claim follows these counts.


## Increment1.9 — actual review / correction rounds

1. Read preserved I-002/I-021 contracts and unchanged Proxy/Blob schema. Replaced
   temp-only references with registered raw+PTS-map CAS resources, immutable
   asset/clip/sequence versions and existing transaction/history pins. Actual
   native save/fork/reopen/original-file export passed. Checked metadata roles,
   exact CFR time bounds and canonical paths; no new root field/schema migration.
2. Corrected cache identity to include frozen source streams/ref/blob metadata,
   enforced declared byte lengths and pre-hash limits, checked post-admission hash,
   kept CAS readers non-owning and generation-fenced stale asynchronous reads.
   Added duplicate/reuse, corruption, missing refs, cycles/path/PTS/overflow,
   real mid-output concurrent edit rejection and original-retaining GC tests.
3. Actual cross-process lock test initially failed: an unresolved Future alone
   allowed the Dart fixture VM to exit, so parent correctly acquired the lock.
   Retained failure; added a real timer-backed live child, then proved parent
   remains blocked until SIGKILL and reclaims the native/copy/map stages. No
   weakening of lock assertion. Files outside ownership and symlink targets stay.
4. Adversarial review: self-consistent hashes can still lie about source pixels.
   Added local trusted-producer records (NOT cryptographic signatures), excluded
   from archives/peer paths and GC-owned by resource pins. Unknown producer is
   requalified once using real native generation and whole raw/facts comparison
   before creating a project. Actual forged archive with recomputed correct
   frame/blob/map checksums now fails PROXY_DERIVATION_MISMATCH; valid independent
   namespace archive qualifies, then reuses. Existing records allow reopen reuse.

First complete 172-case rerun genuinely failed four real-service audio/UI cases
(timeout/stale state/underrun); retained report, not marked all passed. The same
run's offline AAC, independent actual Pulse fault fixture,9 Chrome and real OS
keyring UI passed. Final source rerun and fresh-service diagnosis are recorded
separately; a later pass cannot erase the original failure or qualify P0/AV stress.

Final frozen-source increment1.9 rerun:172 native +9 Chrome +1 actual OS-keyring UI =182 distinct Dart/Flutter,0 skips;6 Python,3 CTest. Six clean Linux release builds/starts and three minimal ABI probes passed. Actual60s offline PCM→AudioBus→AAC/mux, independent private Pulse faults, Pulse-OFF refusal and v4/v5/v6→v7 migrations passed. Verification source hashes match; the first four service failures remain unresolved intermittent-stress evidence, not erased by the passing rerun.


## Increment1.9.1 — small checkpoint reviews

1. Reviewed trust/admission boundaries: inspector imports only pure document/UI
   libraries (no SDK/IO/FFI in reusable widget); arbitrary locators/opaque plugins
   render as text. Native explicit selection is bounded independently before and
   after read, refuses symlinks/nonregular Unix files, closes handle in finally;
   no candidate enters active SQLite or namespace CAS. Core admission unchanged.
2. Actual UI tests exposed lazy menu finder/scroll ambiguity, then a missed tap
   before expanded layout and fake-time IO timeout. Retained failures; tests now
   prove actual menu choice/hit-test, run file IO in real zone with bounded
   completion and assert unchanged SQLite head,undo,reopen. No ignored warnings.
   Reviewed disposed load epoch and last-valid-snapshot retention on rejection.
3. Browser test import outside served app root initially failed compilation.
   Moved only synthetic browser test fixture inside that app; shared production
   inspector is unchanged and actual Chrome now passes three cases. Reviewed all
   root keys/opaque preservation and bounded paged output; no media-byte validity
   inferred. Clean analyzer,10 non-audio native UI plus3 actual native proxy cases
   passed. Full182 and release results remain attributed to e11ce9a, not this UI
   checkpoint; physical/platform/audio-stress gaps unchanged.


## Increment1.9.2 — three actual small-batch reviews/corrections

1. Reviewed old/new-root admission, controlled SDK operation, revision/writer CAS
   and version propagation. Kept old-root strict admission: unsupported proxy
   recipes cannot silently enter editing. Explicit consent is required; no disk
   mutation is in discard. Corrected test's existing export API name before run.
2. Reviewed actual UI consent lifecycle: bind to snapshot hash AND selected clip,
   reset after revision/selection, disable action while busy. Corrected obsolete
   ephemeral/clear labels and exposed built vs reused counts. Actual UI tap,
   revision advance, cleared consent and undo pass, not a mocked controller call.
3. Reviewed closure/history risks and added actual two-asset shared-hash case:
   only unused derived metadata is removed; other asset and shared blobs remain.
   Added busy-build refusal/cancel, duplicate no-op, stale CAS, missing-file native
   rebuild and corrupted bytes. Corrupt collision stays fail-closed; no unsafe
   replacement or original deletion added to make the test pass. Original-source
   export/archive/fork/reopen and history-pinned GC preservation actually pass.

Final source hashes/evidence:78 targeted executions,0 skips, clean analyzer.
No release/full-suite/browser/audio-stress rerun or physical-platform claim.
Namespace quota/pruning and corrupt-CAS replacement remain explicit next work.


## Increment1.9.3 — three actual review/correction rounds

1. Audited source provenance, hash/recipe admission and all-history role authority.
   Real tests exposed that snapshots also holds intents/entities, not just roots.
   Corrected scan to hash-check every object and validate project candidates;
   original/unknown roles and other-project pins still fail before publication.
   No Admission switch-off or reclassification of unsafe bytes was introduced.
2. Real writer-fence test exposed checkpoint WRITER_FENCED on close leaking
   resources. Close now skips ONLY that stale write and closes; other failures
   propagate. Real fault fixture initially exited255 because append on pipe stdout
   attempted seek; retained diagnostic, corrected writeOnly, then actual SIGKILL
   after first durable publication proved partial state/prepared audit and repair
   on reopen. Pair atomicity is explicitly NOT claimed.
3. Adversarial ownership review found that another SQLite DB could share the CAS
   namespace outside the scanned DB. Added known-empty creation owner binding and
   permanent per-DB usage markers; legacy nonempty/multiple-user CAS cannot gain
   repair authority. Actual legacy, second DB, symlink, original-role and shared
   fork refusals pass. Actual clickable UI restores corrupt CAS with unchanged
   project hash/revision. Default no history/file pruning; valid bytes are untouched.

Final frozen sources:63 store/SDK +3 native UI =66 targeted executions,0 skips;
three focused cases were rerun but are already in63. Analyzer clean. No full182,
release/browser/P0/physical multi-device or underrun-fix claim. SQLite3.54.1 strict
runtime and original87/XD10 status/acceptance remain unchanged.


## Increment1.9.4 — three actual review/correction rounds

1. Read original s5b StoragePort reserve/freeBytes and s7a storage/export boundaries,
   existing namespace OS maintenance lease/repair owner binding and peer64MiB /
   preview64MiB bounds. Kept them; no incompatible budget SQL table/Project field.
   Inventory includes stages/unknown files/metadata, not just canonical objects.
   Closed policy schema, explicit namespace UI consent, preserveAll default and
   exclusive fresh DB authority were reviewed. No pruning/deletion/ENOSPC claim.
2. Audited reservation lifetime across SDK build/repair/foreign qualification and
   nested import/map publication. Found source size can grow while an import is
   queued behind maintenance lease; captured source size now bounds both initial
   stat and each chunk BEFORE sink.add. Added actual queued256→8192 growth race.
   Canonical lease paths prevent lexical aliases splitting the in-process queue.
   Actual child lock/SIGKILL proves no early reclaim;16KiB stage stays inventoried.
   Caller failure/cancel release accounting, not files. Existing scope/dependency
   code was inspected; native C++ and approved SQLite runtime gate are unchanged.
3. Re-read default/disabled cap, metadata journal, shared/legacy authority and
   UI consent invalidation. Added adversarial numeric/future/malformed policy,
   unsafe symlink and unmanaged native-stage tests: fail closed without changing
   project revision or touching outside fixture. Two6000-byte publishers under
   tight cap admit one, not both. All fixtures are private systemTemp roots;
   no cleanup was run on user/other-agent data. Actual archive/fork/reopen and
   existing CAS repair/history/cancel/transaction regression selected below pass.

Final source hashes in namespace-budget/summary.json:66 store/SDK +4 native UI
=70 targeted successes,0 skips; analyzer/format clean. Earlier65+4 pre-final
runs are not combined; final includes third malformed/unsafe policy test. No
full182, native rebuild/CTest/ABI, release/Chrome, full historical migration matrix
or audio-stress/P0 rerun. Intermittent service underrun remains unresolved.
Conservative logical-byte budget is not full disk/DB/export reservation, physical
platform qualification or history pruning; original87/XD10 counts unchanged.

Final hygiene correction: cached diff check detected trailing Flutter console progress
padding in the newly added analyzer evidence. Initial source commit retained;
normal documentation-only follow-up removes padding, records testedSourceCommit,
and reruns full base-to-index text/credential/whitespace checks. No source or
test-result change; source hashes remain the exact70-test freeze.


## Increment1.9.5 — three actual review/correction rounds

1. Re-read s5b and s5d: actual resource GC needs full roots/grace and original age
   windows lack trustworthy timestamps in current checkpoint rows. Kept runtime
   preserveAll per user and explicitly limited opt-in policy to checkpoint index
   rows. No commands/snapshots/undo/role/blob edges/files removed; no CAS/disk-free
   claim. Added permanent unique named checkpoint labels rather than fake pinning.
   Reused namespace owner proof/OS lease and SQL transaction/migration checksums.
2. Reviewed stale/foreign replay and mutation races: receipt lookup is now project-
   scoped, live revision/writer validated even on retry, old owner/fence cannot
   replay after takeover; full root metadata/policy/labels/candidates bind review.
   Historical snapshot hashes/project/namespace/revisions and label/pointer closure
   validate before deletion. Added real SQL post-delete audit failure, final-owner
   failure and SIGKILL before COMMIT, followed by fenced reopen/review/commit.
   No production test bypass or direct-SQL simulated pruning substituted.
3. Reviewed actual UI and bounds: initial failed assertion searched offscreen lazy
   text; retained failure, explicitly scroll to review and wait on real media-busy
   lifecycle. Consent is consumed before apply (including refusal); edits/new pins
   are checked again by transaction. Bounded rows/labels/root text and DISTINCT
   save checkpoint selection avoid pretending truncated reviews are complete.
   Added readable hash-verified audit history (including result-vs-review tamper refusal), fixture-only kill-worker path guard,
   actual native import/proxy/undo/archive/fork/reopen/original-byte preservation,
   shared DB refusal, v7→v8 migration and injected partial-DDL rollback tests.

Final tests/counts/source hashes are frozen in checkpoint-retention/summary.json.
Initial UI/analyzer failures retained; interpolation/lint development issues fixed
before final run. No old182 reuse, whole-repo/release/Chrome/audio stress or full
historic migration matrix qualification. Runtime gate unchanged; intermittent
underrun unresolved. Full age-window/resource-history pruning remains unfinished.


## Increment1.10 — three actual review/correction rounds

1. Read exact s5/s5a/s5d and generated Font/Blob/Effect/Layer/RetainedSource fields.
   Core has no LUT/library first-class schema: did NOT guess vendor hash strings
   or claim closure from an opaque object. Registered core references report
   missing-declaration vs missing-byte vs role/opaque issues. Format/notRun and
   render=false remain distinct. Kept strict default editor/archive admission;
   preservation is a separate read-only file view, with NO new DB/CAS subsystem.
2. Actual first SDK tests found missing typed track.sequenceId/clip.trackId fork
   backlinks and an invalid test extension key. Fixed typed parents; source hash,
   external license/model IDs and literal text are not generically replaced.
   Reviewed archive refactor and corrected default CAS reads to bound streaming
   to remaining expanded budget before accumulation. Existing size-error contract
   retained; font/generated manifest groups reflected. Added mature link(2)
   no-clobber publication and actual prepared TWO-PROCESS winner/loser experiment,
   cancel/stale-consent/symlink/existing-output checks; only own stages removed.
3. Actual UI tests initially could not find fixture from package cwd; fixed test
   fixture root from explicit synthetic video env. Old repair regression later
   searched a lazily evicted checkbox after scrolling; retained actual failure,
   explicitly locate checkbox again and still assert its false value/raw CAS
   restoration/unchanged revision. No assertion/qualification gate weakened.
   New UI actual load/collect/consent/archive/reopen/fork proves active head/CAS
   inventory unchanged. Reviewed disposal cancellation, private byte copies, source
   change limits and confirmation invalidation. Native/source/font/PNG, separate
   process reopen, domain/history/quota/repair regressions and offline actual
   Chrome pure-core boundary are final evidence; no RTC positive test rerun.

Final frozen-source command counts/source hashes are in resource-preservation/
summary.json. Initial SDK/UI failures retained. No old182 result or audio-stress/
release/full migration matrix/physical multi-device completion is borrowed.
Intermittent audio underrun remains unresolved; rich writable import/render and
full registered library/retained-definition closure remain explicit next scope.

Final process-barrier review: the initial two-process test exposed a TEST harness
error, not a publication success: opening `/dev/stdout` with File flush requested
fsync on a pipe (EINVAL), and a multi-byte parent signal could hit broken-pipe
after child exit. Retained both failed broad-run logs. Corrected the worker to
Dart stdout.writeln + await stdout.flush and an explicitly checked one-byte async
stdin barrier; included child stderr/exit codes in assertion diagnostics. Then
reran the complete selected freeze, rather than borrowing the earlier141 pass.
Production link(2) publication/error requirements were not relaxed.

## Increment1.11 — three actual review/correction rounds

1. **Original-contract/domain review.** Read exact s5a retained-definition contract:
   it requires complete ProjectDocument snapshots, not isolated guessed definitions.
   Implemented strict hash/size-limited parsing, origin and exact kind/id/version,
   dependency role/pins, opaque diagnostics, depth8/count bounds and conflicting
   literal definition checks. Tests include missing/hash/wrong origin/version,
   nested pin/depth failures and actual archive/reopen. Explicitly NOT full resolved
   render-definition equivalence. No LUT/library schema/registry invented.
2. **Publication/authority review.** Writable adoption uses existing renderer
   compiler and namespace reservation/maintenance lease; actual probe facts must
   equal declarations, first-frame/PCM/proxy qualification then final CAS/hash and
   writer/selected-head transaction. Found recursive fork `id` enumeration was not
   an adequate ImportMap basis: changed to exact supported entity enumeration.
   Added v9 map with creation/selection/writer/checkpoint in one transaction and
   real map-trigger rollback/takeover/crash recovery. Actual SIGKILL asserted, not
   merely any nonzero exit. Review found old prune test's pipe fsync barrier could
   error before being killed; corrected TEST worker to a non-fsync pipe write and
   asserted the exact SIGKILL exit, retaining the same prune/rollback requirements.
3. **Actual user-path/native/failure review.** Initial positive schema-golden
   fixture correctly failed native metadata equality (profile unknown/null).
   Kept the strict gate and original golden; successful source now uses the actual
   importer, including a separate origin namespace. Actual native AAC/PCM/export,
   missing unsupported resources, budget refusal/no reservation leakage,
   cancel/intervening revision, UI consent/new writable project/map and reopen are
   tested. Corrected the old panel-wide no-DB-write disclaimer to distinguish
   read-only inspection from the new explicitly confirmed writable-fork action.
   An exploratory broad run lacked the required private Pulse endpoint and
   failed AUDIO_DEVICE_LOST; retained the log, then used the existing isolated
   software-service harness serially. No desktop audio settings, network policy,
   RTC test, renderer capability or assertion was relaxed.

Frozen source hashes/final commands/results and real historical migration evidence
are in resource-admission/summary.json. No previous182 result is borrowed; an
isolated software service pass cannot establish physical presentation or resolve
the historical intermittent underrun. Full original tasks remain partial.

## Increment1.12 — three actual review/correction rounds

1. **s5a dependency semantics.** Replaced literal retained-target hashing with a
   typed canonical definition/dependency graph. Checked exact retained source
   origin/version, no-latest resolution, parent reverse-edge exclusions and image
   forward hierarchy, font/mask/core effect and actual audio-bus dependencies.
   Unknown semantics remain unqualified; no renderer/admission capability added.
2. **Ownership/version/persistence review.** Found nested references must resolve
   in their OWN snapshot context, not the outer current root. Registered all media
   definitions in each snapshot to catch transitive same-version conflicts. Added
   the current before/after guard before existing SQL publication; explicitly did
   not rewrite historical v9 hashes or claim historical version-reuse completion.
   New test imports were fixed; a depth fixture actually changed source data with
   unchanged clip/sequence versions, so raised those versions rather than relaxing
   the conflict/depth checks. Original failing log retained.
3. **Consumer/performance/platform review.** Actual mix48k gain/pan PCM consumption
   changes with the definition dependency identity; root project title does not.
   Avoided quadratic image-child scans and repeated full JSON/hash parsing per
   node via immutable-context caches/typed indexes. Added actual Chrome identity/
   version-guard case and reran existing actual native AAC/resource adoption/edit/
   archive/reopen, SQL fault/SIGKILL, pins/budget/fence and isolated service tests.
   Final actual AAC/private-service runs exposed a real pre-existing SetMasterAudio
   propagation omission: bus state changed without advancing its owning sequence.
   Fixed the production allocator path and added explicit version/no-op regression.
   Corrected Chrome fixture to request actual empty sequence version0, not1.
   A further manual schema review found track/sequence-owned effect order is not
   qualified by this profile; refuse it explicitly rather than silently omit its
   dependency. Added two retained-data-preserving negative cases plus a clip-owned
   core-effect parameter identity test. No execution permission is inferred.
   After that correction, native AAC passed; the private service reproduced its
   known resume underrun (full log retained, no timing/assertion relaxation).
   Digest reporting always says no render-equivalence proof. No old full-suite,
   GPU/physical/nonLinux/RTC result is borrowed; underrun remains unresolved.

## Increment1.13 — three executed history compatibility reviews

1. **Source authority/old history.** Inspected actual old `_registerDefinitions`
   algorithms and existing publication/undo ordering. Kept all legacy hashes and
   schema9 unchanged; only exact anchored, hash/namespace/project/revision-checked
   snapshots certify known typed definitions. Added noncurrent reuse/orphan/raw
   corruption tests. Recognized old same-version bus ambiguity must allow exact
   validated undo, not grant arbitrary restoration or falsely flag the old file
   corrupt. Current-head-only guard now defers to full history for that undo path.
2. **Rollback/concurrency/bounds.** Checked every root publication site (create and
   _commit), savepoint failures and PRAGMA data_version. Cache clears on rollback,
   external connection change and project switches. Failed or read-only proposed
   checks never teach it. Removed duplicate candidate resolution and an unused
   scan. Added true late SQL abort, other-connection, zero-cache/invalid-limit,
   missing-counter and bad historical source tests. No new disk index/protocol.
3. **Positive compatibility/fault evidence.** Added a real SQL parent-location
   fixture to execute the valid canonical-equal/raw-different publication branch
   while asserting the old row/source bytes stay identical. Actual old libraries
   for BOTH store+document produced legacy ambiguity; current undo/rename/re-edit
   and SIGKILL/reopen checked old byte preservation. Corrected only fixture barrier
   quoting and probe braces after actual failure; logs kept. Archive/fork/reopen and
   long1000 edit/undo tests reran. No production native audio/timing change and no
   renderer admission widened; historical underrun still unresolved. Instrumented
   crash mirror is explicitly separate from unmodified frozen test execution.


## increment1.14 — 实际静态 opacity 消费（三轮实审）

1. **领域/事务/语义审查**：核对原 I-008/I-022/s4，不把单节点说成完整 registry。发现 split 继承 effect owner 和抽取音频复制视觉 effect 风险，增加新 clip 独立 effect ID/owner、删除当前孤立节点、音频 effectIds 清空；历史不可变。验证 bounds/identity/noop/锁路径、旧 pluginVersion/extension 拒绝、linked split。测试初稿 DeleteClip/NativeMedia/Namespace/preview API 参数编译失败保留，按真实签名修复。
2. **像素/颜色/生命周期审查**：不能给 proxy 缩图直接乘非线性像素，改为原件全尺寸共享 native 节点和实际 YUV420 encoder-input 取样。保留 identity 旧路径；FP32 transfer+RGB8 staging 与 FP16 GPU 规范偏差写 ADR0021。检查 writable/COW/RAII/每32行取消，补最终转换后取消及取样前正确 PTS；严格4样本/64资格上限、range/duplicate拒绝。灰块 fixture 缺 primaries/transfer 导致 COLOR_POLICY_REQUIRED，修 fixture setparams 不放宽门禁；独立数学参考及真实编码前像素检验。
3. **用户路径/准入/失效审查**：初稿误用不存在的 UI 解码 API，换真实 callback+Completer、2秒deadline、迟到 dispose、mounted/hash/selection fence。资源采纳不能只查 capability，必须实际执行 bounded native effect 后才原子 fork；真实采纳/ZIP fork/重开/undo/预览/MP4/UI点击测试。无效 NativeMedia 参数是同步 throw，修测试捕获方式；最终 analyzer 一条括号风格失败保留并修复，冻结后重新跑选定套件。数量不等于原任务完成，未重跑项和未解 underrun 单列证据。

补充真实失败：冻结后旧 local_video_ui_test 的 restore-archive 点击落在未绘制的视口边缘并超时（保留 hit-test 日志），不是把超时放宽或关 warning。新旧测试均改为居中 ensureVisible→pumpAndSettle→hitTestable 断言后真实点击，完整9项 UI 重新通过。新增 AudioSink-clock opacity 测试起初给纯视频直接播放，正确触发 PERSISTENT_AUDIO_REQUIRED；改为实际生成 AAC 输入并持久抽取 AudioClip，不放松门禁，再进行隔离服务资格。最终测试以新冻结哈希列出。


## increment1.15 — 真实clip-local关键帧/取消（三轮实审）

1. **原合同/时间/编辑**：逐条读s3/s5a owner-local/数值合同，采用项目交付帧→clip-local→source映射；拒off-grid执行，不复制C++插值器。补hold半开边界、端点hold、replace/noop/remove、split/right owner+point独立ID、边界裁切重基准、linked音频不继承视觉曲线、slip保持本地曲线。发现静态Apply会丢动画、裁切绕过effects锁、编辑会启用disabled节点，均改显式拒绝/保护并加测试；schedule验证排序每segment一次/二分查找，限制256点和帧数预算。
2. **生命周期/实测失败修正**：100次已呈交encoder至少2帧后的真实取消首轮malloc heap corruption（原始日志保留）。定位Input.at在throwing decode前留下current/next别名，修std::exchange转移所有权，非放宽断言。新增应用自有AVFrame计数/真实进度、100 scheduled cancels、FD检查、ASan/UBSan leak detector（未instrument第三方/GPU，不假称完整lease）。原audio_io只把自有frame alloc/free接到相同计数器，原音频回归单独继续。
3. **可用UI/持久与反例**：真实UI整数frame/value/hold输入→原子set/remove→preview→undo/save/fork/export；SDK验归档重开仍有动态非黑帧，split/reopen后cut两侧实际encoder-input像素保持。最初测试误把连续两次last-commit inverse当成多级undo，修为一次命令undo断言，不改存储合同并明确多级栈未完成。原 malformed schedule边界检查在创建输出前拒绝。保留初稿style/脚本路径错误/错误undo假设，最终所有结果按新冻结哈希；旧underrun/旧writer限制不消除。最终回归发现将旧sample强制帧量化破坏原精确source映射断言，未改旧断言：恢复sample精确语义，新增显式sampleFrame供SDK呈现消费者使用，二者补边界回归并重新冻结。真实Pulse新增曲线测试又发现初稿将YUV420→RGB8 nominal black误当理想RGB0，实际1；沿既有static-node golden的0..1及原V-003≤2/255（非新放宽）补独立显式opacity0参考逐字节相等，alpha仍必须255，保留失败日志并重跑冻结矩阵。最后预算复核发现分片schedule已有120000上限但SDK整体上限只在native端拦截，补在分配任何曲线数组之前的总帧数门禁（复用同一120000），真实MoveClip形成5000秒以上工程/拒导出/无产物测试（初始外来JSON fixture先被duration一致性/已有导入时长门禁拒绝，保留两次失败，未放松这些门禁），不默裁短片或更改原验收。


## increment1.16 — 静态transform真实消费者（三轮实审）

1. **原s4/s7a语义与版本审查**：检查M乘法次序、画布像素/源归一anchor、Y向下正旋转、像素中心/越界transparent和linear双线性。实现完整七个静态参数；明确UI uniform/source-center子集；拒未实现动画/未知节点/重复和逆序节点。改原opacity-only的single-effect假设为有序transform→opacity，set/remove关键帧和静态opacity不会覆盖transform；split owner复制、trim/slip关键帧域裁切继续原合同。domain逐90帧对比和锁/noop/坏输入覆盖，未增存储协议。
2. **native/资源/安全审查**：共享全源像素节点先transform后opacity，输出前严格recipe校验，capability显式门禁、缓存含完整transform、identity真bypass。逆矩阵有限范围/越界先判再转int；两个有界RGBA8 buffers、每32行epoch检查、原总帧门禁保留。review后把transform解析移到segment编译阶段，identity只判断一次；保留std::exchange反双释放修复及原opacity100取消，再新增transform+curve100活动取消；普通及ASan/UBSan分别测，不误称codec/GPU内部资格。
3. **实际用户路径与反例审查**：真实FFI UI编辑/预览/undo/save/fork/export；独立白图半像素coverage线性reference、非等比缩放/90°旋转/anchor/平移/identity、真实编码前像素、SQL重开/归档fork/split和服务确认clock。初稿SDK expectedRevision错用String被analyzer拒绝、测试无效cast被发现并修正；white fixture只有容器色标而无实际transfer/primaries，生产门禁正确拒绝，补与既有golden相同setparams后通过，不放宽颜色或像素门槛。再次审查发现公开preview可持有调用者可变map，cache key与await后recipe可能分离，补首个await前不可变捕获/参数验证，并加调用后立即改map的真实像素回归；增加非等比缩放golden。首次最终矩阵记录一条UI大括号style失败，另新增取消mode分派未匹配导致unknown test（不是取消通过或资源故障），两类失败均保留；修正分派并实际运行后重新冻结。最终所有选择测试按新冻结源单独记录；原underrun/旧writer/平台限制不消除。


## increment1.17 — VIDEO dissolve / source handles（三轮实审及修正）

1. **原时域/编辑/历史审查**：核对s4窗口[b-p,b+q)、源handles、linear-light混合和s5 Transition；仅开1x/linear/reject，原语义校验保留。共同图按project/source同一时间求两条腿，opacity在handle范围hold端值；split/trim/move/roll/slide保守要求显式移除，slip重新验handles，不静默丢transition。真实set命令最初被DEFINITION_PROFILE_UNQUALIFIED拒绝，补同一已执行子集的Sequence依赖闭包，保留无转场旧指纹。下一实测DEFINITION_HISTORY_UNQUALIFIED揭露legacy kind已有`transitions`，改用原kind而非新建singular store键/迁移；两次失败保留。
2. **真实像素/生命周期审查**：逐腿先transform/opacity，再捕获FP32 linear RGB混合，最后一次RGB8→YUV420，不混display缩图/YUV。只两个解码Input、维度/颜色/整数mix schedule/帧数严格验、每32行取消；保留std::exchange所有权修复。初稿range helper绕过旧schedule大小检查，补公开range及独立graph编译前120000上限并加坏count测试。保留旧两种100取消，新增实际双源/transform/curve模式；不能用mock计数或准备阶段cancel充数，也不说GPU/codec内部已instrument。
3. **UI/归档/失败原子性审查**：真实FFI UI设置p/q→预览→单次undo→保存/fork/MP4；实际软件AudioSink sample48000选择两个effected leg并比timeline同帧，不拿wall clock推视频。真实archive fork报REF_NOT_FOUND，修既有typed ImportMap的transition/effect owned IDs及两clip端点/effectIds，不清空effects。加fork ID不复用/关闭重开像素相等、真实SQLite late events trigger abort（仅fixture）、版本行数/当前根回滚、stale revision、双leg sequence指纹闭包与无效复用拒绝；单次undo除单调revision外payload hash精确恢复。修UI旧“No AudioSink yet”误导文本，明确video不加audio fade。测试初稿用了不存在guard名称被analyzer拒绝，按现有verifyDefinitionTransition修复，失败保留。最终源码冻结后再独立跑所选矩阵，不混用旧216/209；不消除既有underrun/旧writer/物理与GPU缺口。

补充收口审查：第一轮冻结矩阵实际复现旧opacity_clock的service underrun，保留完整非零日志，不改队列/timeout/断言，不以新dissolve-clock通过宣称已修复。随后检查资源感知可写采纳，发现既有资格循环只探opacity、遗漏transform以及两源联合作用；补真实transform参数和真实window中点双源native probe（仍共用既有图/64节点界限），在事务发布前检查epoch/当前root。新增实际160×90右源：单源解码成功而joint CPU consumer拒绝DISSOLVE_SOURCE_MISMATCH，验证不选中新fork、不改当前ImportMap/原归档；正向受支持双源+效果完整采纳后关闭重开再编码。纯capability或两个独立缩图均不是双源消费者资格。本次补充后重新冻结，前一冻结结果保留为前一版本，不混计为最新全通过。

负例初稿YUV444在既有单源preview格式门禁已被拒绝，尚未达到joint probe；保留PREVIEW_PIXEL_FORMAT_UNSUPPORTED日志，不修改门禁。改实际128×72/160×90两个SDR源，各自可真实生成相同128×72显示缩图，但原件尺寸不兼容；实际全源joint消费者拒绝；正式采纳则保持原graph更早拒绝，不绕门禁，避免“两个缩图可显示就可组合”的假资格。

第二负例初稿也被原TIMELINE_SCALING_UNSUPPORTED在helper预先采纳时拦截，日志保留。这说明既有早期门禁有效；不为达到后门禁而绕开它。改为只读收集完整真实资源，分别调用实际native source previews和joint preview证明“缩图均可显示但全源组合拒绝”，正式采纳继续断言更早的原graph拒绝、当前root/ImportMap和保全归档不变。

最终负例的native preview返回Map而不是SDK frame类，初稿`.width`被analyzer拒绝；改真实`['width']`断言，保留失败，不增加不存在API/不改生产门禁。后续定向native admission与既有resource-admission测试实际通过，再冻结并重新运行所选矩阵。


## increment1.18 — Crop / ColorBasic 真实消费者（三轮实审修正）

1. **原合同/准入/事务审查**：逐条核对原 s4 CropParams/ColorBasic、canonical 操作次序、静态参数范围、未知/disabled/animated 语义与 split 所有权。复用现有 SetClipTransform 的不可变命令和 SQLite 版本/fence 路径，抽成 static visual helper，仅对已准入已知列表插入排序，不重排导入数据。crop 的 source-normalized 边界与 half-open texel-area coverage 在 ADR0025 明确，不能把 CPU 栅格选择称 GPU 已匹配。首轮 analyzer 的16条风格信息保留，按实际 Dart fix/format 修正而非关闭规则。
2. **真实像素/生命周期审查**：检查共享全源 native 节点每腿 crop→transform→color→opacity、最后 dissolve。保留 coverage 内 straight-linear 调色/重新premultiply，完全透明区域不能被 contrast 点亮；signed/over1中间值不能在每腿/曝光阶段 clip。补半像素面积、contrast0/EV+2 后降contrast、超1白腿叠黑不应先clip、实际红源 saturation/luma 的独立参考及真实 preencoder 样本。保留旧 identity 路径、两decoder/内存/每32行取消、std::exchange 修复与旧三种取消mode，新增独立两腿不同crop/color的实际 active raster_cancel，普通/ASan分别验。
3. **UI/缓存/资格/失败原子性审查**：真实7个输入控制器→原命令→preview/单次undo/save/fork/MP4；SDK验证SQL后段trigger失败不发布、stale revision拒绝、归档fork/重开及真实native资源采纳。发现 qualifiedNodes去重键若漏 raster 会复用错误资格，补入完整 raster；公开异步preview首个await前深捕获，实际调用后马上修改外部map仍不改变像素。测试初稿的动画fixture缺 `easing:null`，可能只证明Schema拒绝；改成先真实构造合法ProjectDocument，再断言精确 RASTER_ANIMATION_NOT_IMPLEMENTED 和不剥离keyframes。native12个主/副腿恶意recipe实际创建输出前拒绝，不能只靠领域validator声称安全。最终冻结后重跑所选矩阵，早期仅定向成功不混算，结果/未跑项另列；未更改Pulse队列、timeout或旧失败断言。

最终冻结资格的真实失败：serial矩阵新增raster_clock首次play等待服务确认sample>4800时已interrupted/underrun1（presented2877、submitted5168、ring8192/8192、maxWorkerLoopGap2425us、serviceLatency25894us），抛于line116，尚未执行该测试line127的timeline-render/seek像素断言。早期同案例单独定向通过不是本冻结端到端成功；保留完整非零log，不改队列/timeout/阈值、不刷绿。本轮旧opacity_clock通过也不消除00c2e5d已记录失败。根因未定位，不能据该日志猜测是crop像素负载或声卡性能。最终233所选中232过1失败；其他实际像素/UI/归档/取消资格与失败分列。


## increment1.19 — 真实Pulse调度/诊断（三轮实审修正）

1. **证据与因果审查**：保全e23a559/未发布handoff、旧raster presented2877首次启动失败及00c opacity失败。先仅加诊断跑一次两case和一次旧monitor/fault probe，均通过，不能说根因复现/解决。读官方Pulse mainloop/buffer文档；只确认原nonblocking iterate后无条件sleep会延迟已ready工作，决定用官方prepare/poll/dispatch和同样2000us最长请求等待替代，不凭测试绿猜根因、不用prebuf0或扩队列掩盖。远端三次GET空规则/protected=false不能解释commit_refs_rules，未作写重试。
2. **线程/状态/错误审查**：核对prepare单位microseconds、prepare/poll/dispatch全部负返回仍中断；Pulse对象仍只worker访问，没有跨线程wake指针新竞态。控制/cancel、stale/cork/connect deadline、服务确认sample、pause/rebind重建与drain EOF路径不变。修正新增可写诊断的未知值为有符号-1（避免size_t(-1)呈现巨大数），underflow index只记证据不变成时钟；dispatch计数含deferred/timer，不冒称全为IO。原ring/server/写batch/PCM有限门禁不动。
3. **真实故障/回归审查**：加强已有真实probe验证event策略/协商minreq与prebuf保持8192bytes，实际SIGSTOP producer仍须underrun/clockValid=false、sample冻结且记录真实underflow index。原sink suspend、server stop/stale、显式恢复/重复resume、FD/坏输入拒绝仍保留。冻结包含既有crop/color12文件及本批2文件，实际串行执行233定向、monitor/fault、历史SQL/kill、CTest和取消，避免CPU并行污染Pulse；结果及失败按本冻结单列，未重跑范围与未闭合间歇问题如实保留。

最终冻结14源码/测试文件所选233全部通过，另真实monitor/fault probe及800视频取消/CTest3/真实历史kill成功。真实SIGSTOP producer依然触发underrun且clockValid=false并冻结；server-stale/device-lost与显式恢复仍有效。新旧两个间歇case的本次通过不能证明根因闭合，诊断前两case也曾通过的反证和两份历史失败继续单列；不作再次刷绿。本批不push，远端原因未知及无已证实用户纠正动作结论不变。


## increment1.20 — 持久多级Undo/Redo（三轮实审/修正）

1. **原合同/真相与Legacy审查**：逐条读取原s3撤销重做和s5a内容hash、不可变version、导入空栈合同，发现原“undo最新物理command”会切换上一次inverse。选复用同一commands/revisions journal而不是加并列栈表或仅内存实现；旧undoLatest保留实际恢复步骤，不能改写旧raw记录/假造现代redo。确认新content比较仅去Project.revision，恢复实体版本但commit revision单调，未知控制版本拒绝且不吞历史；仅tip/full-root保守冲突，不冒称字段rebase或coalescing。初版analyzer1条style信息保留并修复。
2. **并发/事务/故障审查**：cursor查询改为一条head+left-join journal的SQLite读快照，避免两次读取混合并发head；写路径复用原事务/revision/fence/receipt/definitions/pins/events/outbox，只有原子commit后才改变派生cursor。no-op不清redo，新编辑只逻辑截断redo不删事件。补late SQL events trigger rollback与同receipt幂等、真实两个Isolate/SQLite连接门闩并发undo一胜一冲突、旧writer被fence；发现测试worker先发完成可能让fixture删除早于close，改SQLite close后再发完成。坏JSON统一类型错误；未知版本fixture最初只改payload会先撞inputHash，改成合法inputHash再断言精确HISTORY_FORMAT_UNSUPPORTED，不拿弱反例充数。一次辅助编辑脚本substring未匹配已保留，实际修正后定向重测。
3. **真实用户/历史/媒体审查**：新SDK/真实UI按钮多步撤销重做；实际AV导入/抽取音频/link、crop/color、字幕、持久proxy逐态hash恢复及关闭重开；字幕不能静默丢给MP4，显式undo字幕后原件preview/编码前像素/MP4，再redo并归档fork检查空本地栈。真实旧store+document含seq.version0歧义记录执行四undo四redo/re-edit，旧row/snapshot bytes保持、新版本>历史max；不只是新fixture假兼容。复用源码mirror故障策略做两次COMMIT前/一次未改代码COMMIT后SIGKILL，所有重开都用未改当前库。1000次seeded标题历史完整undo/redo不冒称全部NLE随机序列；UI百万历史/字段级协作/coalescing/其他平台仍缺。新增旧库probe的3条style失败修正后再冻结，选定矩阵重新运行，不借旧233或定向通过。

本轮最终20份源码冻结后，fresh所选239/239、CTest3/3、真实monitor/故障probe、实际旧库与COMMIT前后SIGKILL全部通过；视频四模式普通/ASan各100共800轮，未混算旧结果。`evidence/command-history/summary.json`及逐命令日志记录版本、hash、边界和未跑项。没有新失败不表示原间歇underrun闭合；本批未重试远端、未push，原两未发布提交原样保留。格式/analyzer最终通过，早期style和辅助编辑失败另保留，不删失败证据。


## increment1.21 — 手势ghost/单Command（三轮实审/修正）

1. **原合同与边界审查**：逐条核对原s3“pointer move仅ghost、松手一Command、Escape无写”、固定baseRevision、关键帧coalesce及真实undo/redo。未做时间窗口合并或改写journal；闭合8种现有SDK操作的同clip/同字段组边界（trim edge/ripple、关键帧localTime/interpolation也固定），未知操作/历史版本拒绝。所有candidate从base纯计算，真实版本仍由原事务历史max+1分配；取消/新编辑redo逻辑复用原实现。首轮part必须放export后、brace风格及测试误用save/openArchive API均实际修正，不关闭规则。
2. **并发/资源/取消审查**：失败update必须阻止提交旧值；读取base与writer-fence，最终仍在原事务检查，不自动重试冲突。检查安装版本Slider源码，发现onChangeEnd也可能是arena cancel，添加匹配physical-UP授权门；实际hold后丢给竖向scroll的ghost必须无写。Escape/pointer cancel/切目标/生命周期/close都取消；native image最多一请求+一dirty，generation/hash/handle验晚到结果。发现新clip opacity=1无变化点击仍可能创建identity effect，UI起终值相同取消；move/trim/slip回零明确不分配无意义Gap/version。未泛化剥version做危险语义hash。真实SQL late-abort保留候选和同ID手工重试，不清history或pins。
3. **真实UI/旧库/媒体故障审查**：实际UI40连续MOVE→一undo/redo、真实native ghost图、Escape/CANCEL/scroll-arena、无变化tap及SQL失败后显式Cancel。SQL错误原全局Text在滚动区外未构建，第三次UI测试实际失败；补当前control旁错误，保持原异常断言而非忽略SQL，失败log保留。第四次因辅助脚本cwd错误未应用补丁而再次失败，未算成功；后续正确补丁后重测。首次root运行缺material_ui shader，改用原既有owning-package cwd构建声明资产，不修改主题/渲染或跳过测试。SDK真实多目标拒绝/invalid-release、SQL/并发fence/旧格式、实际child SIGKILL staged100次更新重开；已有AV+AudioClip/link/字幕/proxy测试改真实color手势并保留多级恢复/归档fork/MP4像素。最后冻结26份源码/测试/manifest，重新跑选择矩阵；结果和未跑项另列，不借旧239或182。


第三轮补充公共API回归审查：首份247所选成功后主动检查共享preview helper的调用边界，发现初版expression wrapper会在_requireMedia之前同步求值current；未打开且无adapter时报Null check而非原异步MEDIA_ADAPTER_NOT_INSTALLED。补新反例先真实失败（wrapper-regression-before-fix.jsonl），恢复async/capability-first后该反例通过；重新冻结全部26源码/测试/manifest并完整重跑所选矩阵，首份247不冒充最后SHA。没有更改媒体断言、Pulse队列或通过条件。


最后refreeze实际248/248，222 native/领域/存储/SDK+14 FFI widget+5 Chrome+7私有Pulse，另CTest3、真实monitor/故障probe/旧库与SQL/SIGKILL、四模式普通/ASan800取消全部本次重跑。首轮247不算最后SHA结果；wrapper反例先失败再修正且完整refreeze，不放宽断言。尚未做fresh窗口构建/全仓/全87/完整操作随机矩阵/巨量历史/非Linux/GPU/物理验收，旧underrun两失败继续保留。工具CLI版本当前重新只读查询存toolchain-current.json；没有native重编、SDK安装、模型、付费或网络策略变化。全部旧祖先、原104、87验收依赖保持；仅普通本地提交。


## Increment1.22 / ADR0029 — 三轮实际审查与修正（多选原子移动）

1. **原合同/原子集合/锁与链接审查**：逐项读原s3第25/36/37/41/45/51/53行和
   I-005的验收/硬依赖。实现同轨reject闭包，不循环提交单Clip命令；检查所有成员
   锁和最终区间，锁定/缺失/负起点整组拒绝。首次编译暴露旧sealed switches漏列
   MoveClips，补全两处分派后新纯domain4例通过。请求ID防重复/不可变/原100000上限，
   未实现的跨轨/insert/overwrite/Alt/snap/组/全操作矩阵继续缺口，不假称完成。
2. **真实AV/时域/历史与失败事务审查**：真实合成AAC素材导入、拆分及提取两对链接
   Clip，检查相对offset、clip-local曲线、transform/crop/color、持久代理和字幕原文。
   非零音频offset测试暴露帧间audio尾点可能被直接做成非法video尾Gap，改为ceil帧
   边界，并加+1/-1回移回归；混合29.97/48kHz不整sample拒绝，不拿该metadata测试
   当真实29.97/native性能资格。早期人工fixture遗漏leading Gap/精确maxEnd、旧writer
   接管后未显式重开、dissolve helper误复用AV工程导致失败，均记录并修正有效fixture，
   不是放宽生产断言。加入真实DB整组锁、late SQL rollback/同候选重试、双连接竞争、
   revision/writer fence、100 seeded同类移动及完整root undo/redo；非全随机NLE验收。
3. **实际UI/像素/生命周期/回归审查**：真实checkbox→native ghost→一次提交→多级
   undo/redo→归档fork/MP4；非法update必须禁用旧候选并清除旧ghost（修复原会遗留图），
   错选集不自动裁剪、不自动冲突重试。原始两次UI测试走完影音导出后在测试清理阶段
   timeout，保留失败；把pumpWidget移出test_api teardown至live binding内，显式验证
   closeAsync/保存队列drain，不掩盖失败或取消/故障断言。新真实dissolve双端移动验证
   cut/handles/效果排序与共享preview/preencoder字节一致。最终冻结后独立选测现有
   legacy/SQL/SIGKILL/迁移与资源取消回归，实际结果只从新summary读取，不借用旧248/182。

原underrun失败仍未证根因修复，绿色选测不代表消除；没有重新运行受策略阻塞的RTC。
新源码只做普通本地commit，未push/未改变身份、分支、协议、规则或权限。


## Increment1.23 / ADR0030 — 原I-005吸附三轮实审修正

1. 原s3第25/36/41/45/51/53行、实际admission/有理时间及I-005合同对照：最近优先、
   8逻辑像素闭区间、类型/ID排序、先snap再量化。排除整个选集/链接闭包及其派生Gap
   自目标；marker项目原准入继续拒绝，不剥离语义。改正目标上限最初只计过滤后数量的
   问题，排除流也先计数有界；加入精确zoom/pan、阈值内外、优先级、源排除、残差、
   200 seeded独立暴力oracle和合法marker只读拒绝。无O(帧数)/全对全遍历。
2. SDK/事务/时钟与历史审查：冻结plan hash绑定实际工程revision，元数据门禁先于读取；
   修复stale/foreign plan update在抛错后仍可能留下旧有效ghost可提交的状态，显式失效。
   真实AV4成员、预览/编码前像素、AAC解码PCM静音/信号窗口、保存重开fork、多级undo/redo、
   SQL late abort/同候选手动重试/重复提交/revision/fence/锁/转场整组拒绝。首个碰撞
   fixture误设pointer146导致正确吸回原位而非碰撞，保留失败；改为pointer4明确吸入
   被占用切点，不改生产判据。实际AV元数据的29.97/48k格拒绝与独立audio sample格通过，
   不能冒充29.97新native/物理资格。
3. 实际UI/资源/失败审查：非几何输入错误也必须清旧图并禁止旧candidate提交，不因
   Decimal/zoom错误退回未吸附值。首个UI回归发现Undo/scroll后ExpansionTile虚拟化
   丢展开态，修复为由Viewport父state持有；后续同路径验证。装饰标尺先按精确时间
   裁剪再乘zoom，避免远端目标/非法candidate在paint中溢出；double只画线。真实UI
   8px边界zoom/pan、候选/结果、native ghost、取消、单命令undo-redo、SQL故障和
   cut碰撞拒绝、归档fork/AAC MP4。最终源码冻结后重跑选定历史/旧库/SQL/SIGKILL/
   取消/迁移/音视频回归，结果由当批summary给出，不复用旧261。

这些审查不消除原startup/resume underrun/O(n)/field-aware/旧writer限制，也不完成
全部I-005矩阵或其他平台/物理跨端；原87/XD10分别保持真实状态。

## Increment1.24 — physical pointer timeline (three real reviews/corrections)

1. **Original contract / measured coordinates:** read original I-005 and s3 drag row. Implemented visible clip/ruler hit-test, Shift selection and existing link closure/resolver rather than extending numeric confirmation. Physical UP+recognizer END gate, original grab offset and exact Q after1e-6 logical measurement. First UI attempt mistakenly centered the oversized scroll CONTENT in its test; corrected test to target the visible viewport and actual scroll transform, not production coordinates or snap thresholds. Real slider/wheel tests verify scaled delta and exclude moving/link targets through existing resolver tests. Retained same-track/reject/marker refusal limitations.
2. **Transactions / actual exported endpoint:** SQL trigger after native candidate, concurrent writer epoch, external revision, rapid updates, identity/cancel/Escape/secondary pointer and dissolve endpoint/handles tested with real widget events. Found genuine fractional pointer result119/30s rejected by unchanged AAC gate:190368 vs190400 samples. Reproduced stream metadata, changed FFmpeg movie edit-list timescale to bounded exact LCM instead of padding/loosening verification. Added independent91/119-frame sample/preencoder tests. A reverse physical move is a new versioned edit, not undo; tests now compare exact payload fields while undo still checks full saved sequences.
3. **Resource/lifecycle / failure isolation:** actual ancestor scroll, wheel, focus/lifecycle/row exit and virtualized disposal cancel. Found pending4s Future.timeout after a canceled native request; replaced with explicitly canceled bounded waiters/timers and late-image disposal, not extra fake-time sleeps. Old candidates/native frames cannot become releasable after invalid input. Playback/other workbench actions excluded during capture; failed/concurrent release refreshes changed current state without rebase/retry. A final input-draft review restricts that refresh to actual document changes so cancelling/identity does not overwrite an unrelated unsaved title field; all selected groups rerun on the new freeze rather than reusing the earlier281 run. Final frozen-source selected SDK/UI/legacy-SIGKILL/migration/native cancellation/ASan/service tests are recorded individually; old276 results are not reused. Historical startup/resume underrun is not declared fixed by any passing sample.

## Increment1.25 — internal clipboard / copy-cut-paste / group (three real reviews/corrections)

1. **Keyframe identity and curve preservation:** first algebra paste after `SetOpacityKeyframe` failed with `DUPLICATE_ID at /effects/keyframes` because effect and owner IDs were remapped but cloned keyframe IDs were not. Fixed by remapping every keyframe id in the pasted effect without dropping localTime/value/interpolation. Document tests then passed; curves remain in the payload and in the new document.
2. **Fork remapping and post-fork identity:** after grouping, `adoptPreservedResources` / `forkLocalProject` threw `REF_NOT_FOUND at /selectionGroups/memberClipIds` because selection groups were never assigned new IDs and `memberClipIds` / `selectionGroupId` were not in the reference rewrite. Added `selectionGroups` to the define table and remapped those fields. Tests that locked a track via metadata adopt now re-copy on the new project; the session clipboard is correctly cleared on project identity change and is not a stale-package carry-over.
3. **Paste transition track, SQL mapping, and UI location:** paste now updates transition `trackId` from the destination map (handle durations stay; only `cut` shifts). UI commit failures that are not `StudioException` map to `LOCAL_COMMIT_FAILED`, matching other workbench commits. Widget locate was dragging `Scrollable.first`, which could hit the pointer timeline and replace the checkbox selection with one pasted clip (`GROUP_TOO_SMALL`). The page ListView is keyed `foundation-scroll` and the clipboard UI test jumps that scroller, it does not drag through the timeline surface. Frozen selected document+SDK+UI 7/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; pointer-drag 281 is not mixed in.

These reviews do not close original I-005 (overwrite/insert/new-track/cross-project/OS clipboard/mobile/marker/1000 NLE undo). They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.26 — overwrite paste and move (three real reviews/corrections)

1. **Leftover fragment identity:** the first carve leftover always reuses the original clip id. An earlier `i == 0 && a == start` guard dropped id `b` when only the back of a mid-clip cut remained, so later lookups failed with `Bad state: No element`. After the fix, a front-only remnant is a trim-out and a back-only remnant is a trim-in of the same identity; additional fragments still get new ids and cleared link/selection membership.
2. **Per-interval coverage and dissolve-copy refusal:** a gapped A+C package must not punch the clip sitting in the gap. The first test used paste-at 0.5, which really does overlap B, and was corrected to paste-at 0 so destinations are `[0,1)` and `[2,3)`. Building a clipboard from a project that already held an A–B dissolve while copying only A correctly raises `TRANSITION_COPY_REQUIRES_BOTH`; the affected-dissolve case now pastes a payload built from a dissolve-free project onto the dissolve-bearing one, and the uninvolved later clip stays put.
3. **Traveling dissolve, duration, and UI history identity:** `_deleteAffectedTransitions` kept a fully-moved pair only when dest intervals did not overlap the old handle window, so moving A+B by +0.5s deleted a valid traveling dissolve. The keep rule is now "both endpoints move together," and the cut is shifted after the carve; a dedicated test covers that path. Overwrite paste past the last clip extends duration and does not ripple earlier items. The UI test first compared full document hashes after undo/redo/undo, which fail because undo itself advances revision; assertions now compare sequences and the single revision bump from the post-undo state. SDK tests use a frame-aligned paste time and the real `WRITER_FENCED` code. Frozen selected document+SDK+UI 37/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; pointer-drag 281 and the previous clipboard 7 are not mixed in.

These reviews do not close original I-005 (insert/ripple, new-track, cross-project, OS clipboard, mobile, marker, 1000 NLE undo). They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.27 — insert paste and move (three real reviews/corrections)

1. **Mode boundary and lift rewrite:** opening insert required removing `INSERT_MODE_NOT_IMPLEMENTED` from the shared mode constructor. Overwrite tests that still expected construction-time refusal were updated so reject/overwrite behavior stays asserted and `rippleTrackIds` is illegal on overwrite (`RIPPLE_TRACKS_REQUIRE_INSERT`). A mechanical replace also pointed the existing lift-path `_rewriteMediaTracks` at a paste-only `minimumDuration` name and would not analyze clean; the lift path was restored to the unchanged sequence duration.
2. **Package span, split identity, and traveling dissolves:** insert uses one hole of package-span `L`, not overwrite's per-interval carve, which the gapped A+C case covers. Mid-clip splits keep the original id on the left remnant. A dissolve whose cut equals the insert point is deleted; a dissolve after a mid-clip insert is remapped onto the right remnant and shifted; a fully-moved pair keeps and shifts its cut. Those paths have dedicated document tests.
3. **Link-group schema and caption/fence isolation:** rebuilt right-hand link groups first carried a `version` field that the document schema rejects (`SCHEMA_UNKNOWN_FIELD at /linkGroups/2/version`) on the linked-AV fixture; the field was removed and offsets are recomputed from actual right starts. Importing captions after a still-held second writer failed with `WRITER_FENCED` rather than the caption refusal, so that check is an isolated test. Frozen selected document+SDK+UI 51/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; pointer-drag 281, the previous clipboard 7 and overwrite 37 are not mixed in.

These reviews do not close original I-005 (ripple-delete/trim, source-hole close, new-track, cross-project, OS clipboard, caption cue-follow, mobile, marker, 1000 NLE undo). They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.28 — ripple delete of a single continuous range (three real reviews/corrections)

1. **Command boundary, revision accounting, and selection wiring:** `RippleDeleteClips` is a new command rather than a silent redefinition of `DeleteClip(ripple:true)`, which must still raise `LINKED_RIPPLE_NOT_IMPLEMENTED` on linked AV. Opening it required adding the type to both exhaustive `EditOperation` switches. An unfinished SDK placeholder that used `throwsA(anything)` was rewritten into real lift-contrast, lock, SQL and fence cases; after lift then undo, revision is not `baseline+1`, so the ripple-delete revision assertion uses the post-undo document. The workbench leave-gap Delete button still requires the clip ListTile `_selected`; a multi-select checkbox alone does not enable it.
2. **SQL refusal on `_act`:** workbench `_edit`/`_act` previously caught only `StudioException`, so a SQL trigger abort (`SqliteException`) escaped as an unhandled framework exception on Ripple delete range. `_act` now maps non-Studio failures to `LOCAL_COMMIT_FAILED`, the same class of commit refusal already shown on the clipboard path. The error text is at the bottom of the foundation scroll view, so the UI test jump-locates `Key('error')`.
3. **Honest mid-span crop coverage:** a first document test named mid-span unselected crop only checked later opacity after deleting a middle neighbor and would have over-claimed. That case was renamed, and a real unselected sync-lock audio spanning [0,3) is cropped when only the middle video [1,2) is ripple-deleted, keeping both remnants with remapped source times. Frozen selected document+SDK+UI 64/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (ripple-trim, source-hole close, new-track, cross-project, OS clipboard, caption cue-follow, mobile, marker, 1000 NLE undo). They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.29 — ripple trim shorten (three real reviews/corrections)

1. **Command boundary and lengthen bound:** `RippleTrimClip` is a new command rather than a silent redefinition of `TrimClip(ripple:true)`, which must still raise `LINKED_RIPPLE_NOT_IMPLEMENTED` on linked AV and still shortens video-only sequences on the old single-track path. Leave-gap `TrimClip` still leaves a trailing gap and does not change duration. Lengthening is refused `RIPPLE_TRIM_LENGTHEN_NOT_IMPLEMENTED` rather than guessed; I-006 roll/slip/slide and closing a move source hole stay closed. Opening the command required adding the type to both exhaustive `EditOperation` switches.
2. **Mid-span unselected remnant duration:** a first draft of the unselected sync-lock audio case expected the right remnant after closing [1.5,2) on a [0,3) clip to keep duration 3/2. The algebra splits the later bound first, so the right fragment is [2,3) duration 1, then shifts to [1.5,2.5). The test was corrected to that remnant; the production close path was already right.
3. **Unused selected start:** after review, an unused `oldStart` binding was removed and `oldDuration` is computed from `_start(selected)` so the later-bound vacancy R=[oldEnd-δ, oldEnd) stays the single source of the close interval. Frozen selected document+SDK+UI 75/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (ripple-trim lengthening, source-hole close, new-track, cross-project, OS clipboard, caption cue-follow, mobile, marker, 1000 NLE undo) or I-006. They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.30 — ripple close range (three real reviews/corrections)

1. **MoveClips cannot auto-close:** s3 MoveClips modes are only `reject|overwrite|insert`. Inventing `mode=ripple` or silently closing the vacated source would be out of spec and would break Increment 1.27 tests that assert the source stays a gap. The in-spec completion is DeleteSelection's explicit Range on the already-landed `RippleDeleteClips` command. Clip ids and range are mutually exclusive (`RIPPLE_RANGE_AND_SELECTION`); empty ids without a range still `EMPTY_SELECTION`.
2. **Accidental production overwrite restored:** a packager draft wrote the three bytes `tmp` over `packages/studio_document/lib/ripple.dart`. The file was restored with `git checkout --` from parent `83cc595`, and only the intended constructor/apply range patch was re-applied. Existing clip-id `ripple_delete_test.dart` was re-run and stayed 9/0/0 before the official freeze.
3. **Unused selected binding:** after review, an unused local `moved` in `packages/studio_sdk/test/ripple_close_test.dart` was removed so `dart analyze` of studio_document, studio_sdk and studio_editor_ui is clean. Frozen selected document+SDK+UI 85/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (ripple-trim lengthening, auto-close as part of a move, new-track, cross-project, OS clipboard, caption cue-follow, mobile, marker, 1000 NLE undo) or I-006. They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.31 — ripple trim lengthen (three real reviews/corrections)

1. **In-spec Δ, not a new move mode:** s3 ripple trim first applies the trim, then shifts items after the edit boundary by the duration difference Δ, which may be positive. Auto-close as part of a move is still not a legal MoveClips mode, and insert-move must still leave a source gap. Lengthening is opened on the existing `RippleTrimClip` command; `TrimClip(ripple:true)` is not redefined and still raises `LINKED_RIPPLE_NOT_IMPLEMENTED` on linked AV.
2. **Leave-gap in-lengthen of a packed middle clip:** a first draft of the in-lengthen document test applied leave-gap `TrimClip('b', 'in', -1/2)` and expected duration 3 with start 0.5. On a packed A–B–C timeline that start would overlap A, so the algebra already raises `COLLISION`. The test was corrected to that refusal; the production leave-gap path was already right.
3. **Source exhaustion code:** lengthening past the stream start would have reached `TIME_MAP_MISMATCH` (`sourceStart < 0`) through admission. A preflight `_requireRippleTrimSource` now refuses both a negative source start and a source past the stream duration as `SOURCE_OUT_OF_RANGE`, matching the s3 available-range rule. The existing refuse test was updated from `RIPPLE_TRIM_LENGTHEN_NOT_IMPLEMENTED` to this exhaustion code and still covers over-shorten and insert distinctness. Frozen selected document+SDK+UI 95/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (auto-close as part of a move, new-track, cross-project, OS clipboard, caption cue-follow, mobile, marker, 1000 NLE undo) or I-006. They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.32 — ignore links and groups for a single move (three real reviews/corrections)

1. **In-spec flag, not a new move mode:** auto-close as part of a move is still not a legal MoveClips mode, and insert-move must still leave a source gap. Caption cue-follow would require admitting non-absolute caption anchors (mid-timeline edits with captions still raise `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`). Marker business is still gated by `FEATURE_NOT_IMPLEMENTED`. The remaining already-defined small-batch item is `MoveClips.includeLinks=false` / Alt ignore of link and selection-group closure, with `allowOutOfSync` and unchanged offsets. Overwrite group repair was also corrected to keep a complete two-member group when `syncPolicy` is `allowOutOfSync`, so a later overwrite does not silently drop that link.
2. **Packed later-clip collision and fork IDs:** the first SDK/UI fixtures moved the first 1.5s clip of a packed 1.5s+1.5s pair by +1/2, which overlaps the later clip even when the partner is left behind, and then read `linkGroups[0]` (the unmoved first pair, still `preserve`). Tests now move the last clip into open time and look up `syncPolicy` by clip. After archive fork, clip IDs are remapped; post-restore policy checks use the restored document's last clip, not the pre-fork id.
3. **Official UI cache after the taller controls:** the first frozen selected UI run failed insert and clipboard at `undo` because the added ignore-links copy and checkbox made the workbench tall enough that the top action row unmounted outside ListView's default 250px cache, and jump-locate then moved an inner TextField scrollable. `foundation-scroll` now uses `scrollCacheExtent: ScrollCacheExtent.pixels(8000)` and the checkbox is a compact row. Sources were re-frozen and the official suite re-run: selected document+SDK+UI 104/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous ripple-trim-lengthen 95, ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (auto-close as part of a move, new-track, cross-project, OS clipboard, caption cue-follow, mobile, marker, 1000 NLE undo) or I-006. They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.33 — follow clip-local captions when a host clip moves (three real reviews/corrections)

1. **Writable admission, not fromJson:** a source-anchor caption is still a legal generic document; `ProjectDocument.fromJson` must not start refusing it. Writable admission (`CaptionCue.fromProjectJson` / `expandedMoveClipIds` / MoveClips) still raises `CAPTION_RICH_EDIT_NOT_IMPLEMENTED` for source/style/words/speaker. A cue past the host is `ANCHOR_OUT_OF_RANGE`. Ripple delete/trim/close and insert paste stay `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` when a cue would have to shift or be cropped.
2. **Attach after the host has already moved:** an existing SDK regression imported an absolute 0–1s cue, moved every clip by +1s (the cue stayed at 0), then tried to attach it to the first clip now starting at 1s. That is `ANCHOR_OUT_OF_RANGE`, not a follow failure. The test now undoes the absolute move before anchoring, then moves again and expects the cue to follow; undo is compared with `contents` (revision excluded), not the document hash.
3. **Caption panel and archive gesture:** the caption editor lives in a collapsed `caption-panel` ExpansionTile at the bottom of a tall foundation list. Locate must jump the list’s own Scrollable through to `maxScrollExtent` and then `ensureVisible`, or the tile exists in the tree but is not hit-testable. After a failed SQL preview, `cancel-multi-move` must run before archive, and the pre-fork project id is read after save, matching the already-delivered ignore-links path. Official selected document+SDK+UI 119/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous ignore-links 104, ripple-trim-lengthen 95, ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (auto-close as part of a move, new-track, cross-project, OS clipboard, ripple cue crop/split, marker, 1000 NLE undo) or I-006. They do not fix underrun, old-writer schema9, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.34 — crop and shift captions across a ripple or insert interval (three real reviews/corrections)

1. **Insert-move hosts are gone during the hole:** `_insertMoveClips` removes the moved clips before `_openInsertHole`. Applying the caption interval transform inside the hole rebound a clipLocal cue onto leftover audio, or raised `ANCHOR_OUT_OF_RANGE` when both AV hosts were temporarily missing, and broke the already-delivered insert-move follow path (cue stayed at 0 instead of following the placed host). Insert-move now applies captions only after the clips are placed again; insert paste still applies in the hole because existing hosts remain.
2. **Admission and fixture edges, not silent drops:** a “fully inside” cue cannot be admitted alongside a spanning cue (`CAPTION_OVERLAP`), so the drop path is a separate command. The original video id after a mid-timeline close is the left remnant, not the sum of both remnants. An insert-open right remnant starts at `at+L` (the package span, not the move delta). Ripple-trim lengthen-out on a fully used 3s source is `SOURCE_OUT_OF_RANGE`; lengthen with captions is covered by the packed-clip SDK test.
3. **Official UI locate after caption-panel + close fields:** the first UI run could not hit-test `undo` because locate walked a nested TextField Scrollable. The test now uses the foundation list’s own Scrollable (same as the ripple-close UI path) and `pumpAndSettle` after close. Official selected document+SDK+UI 128/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous caption-follow 119, ignore-links 104, ripple-trim-lengthen 95, ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (auto-close as part of a move, new-track, cross-project, OS clipboard, marker, 1000 NLE undo) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.35 — new and imported cues default to clipLocal when uniquely covered (three real reviews/corrections)

1. **Existing IDs stay authored-absolute:** defaulting every absolute cue on SetCaptions would undo “Make selected cue absolute” and would silently convert later-absolute interval tests (a new later cue on a 3s host, or an insert-move absolute sibling). Auto-anchor applies only when the incoming ID is new. Tests that still need an authored absolute cue on a covered host add then `makeAbsolute`.
2. **Packed-fixture import of 0–1s is now clipLocal:** the first clip of the 1.5s+1.5s fixture fully covers that range, so the old “absolute captions preserved” move assertion would fail for a honest reason. The SDK regression now expects follow after import, then `makeAbsolute` to prove an explicit absolute cue does not follow. A 0–2s import still spans the cut and stays absolute, preserving interval crop tests.
3. **Undo comparison:** the spanning-import SDK test first compared document hash after undo and failed; prior increments already compare `contents()` (revision excluded). Official selected document+SDK+UI 134/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous caption-interval 128, caption-follow 119, ignore-links 104, ripple-trim-lengthen 95, ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (auto-close as part of a move, new-track, cross-project, OS clipboard, marker, 1000 NLE undo) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.36 — admit sequence markers that follow or ripple (three real reviews/corrections)

1. **Writable admission and duration:** Dart `Set` equality is identity, so an empty `markerIds` compared with `!=` falsely refused every existing project. Admission now checks length and membership. `extendSequenceForMarkers` was removed after ripple close of a later ripple=false marker failed `DURATION_MISMATCH`; sequence duration stays the media extent, and a marker may remain at an authored time past that extent.
2. **Insert-move and host absence:** clipLocal locals must be snapshotted before hosts move. `_openInsertHole` must not snapshot after insert-move has already lifted the moving clips, or it would throw `ANCHOR_OUT_OF_RANGE`. Caption/marker interval for insert-move stays deferred until after placement so an unsplit host is not split at the destination hole; the source is still left as a gap.
3. **Point markers and UI admission:** `TimeRange` rejects duration 0, so Add marker on covering clip at a point threw `INVALID_RANGE`. `coveringMarkerHostClipId` covers points with a half-open host test and is used only on the marker path; caption-follow-clip was accidentally rewritten in a replace and was restored to `coveringCaptionHostClipId`. Lifting a clipLocal host is refused atomically as `REF_NOT_FOUND` by the existing validator. Official selected document+SDK+UI 152/0/0 plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous caption-default 134, caption-interval 128, caption-follow 119, ignore-links 104, ripple-trim-lengthen 95, ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (auto-close as part of a move, new-track, cross-project, OS clipboard, 1000 NLE undo) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.37 — explicit source caption anchors reproject with their host (three real reviews/corrections)

1. **Version bump after source reprojection:** `applySourceCaptionAbsolutes` first rewrote `timelineRange` and `anchor.range` without allocating a new cue version, then `followClipLocalCaptions` saw an already-matching projection and skipped its own bump. The store refused the commit as `IMMUTABLE_VERSION_CONFLICT`. The apply path now captures previous host/local/timeline values, writes the projection, and bumps only when something changed, passing the same `VersionAllocator` used by follow and interval.
2. **Remnant rebind after a head close:** ripple close of an earlier interval can leave the original host id on a left remnant whose source window no longer holds the cue. Comparing only that id falsely refused a later source cue that still lived on the right remnant. Snapshots now store the host stream id and absolute source time; apply rebinds to the unique same-stream remnant that still fully covers that window, or refuses if none (or more than one) remains. The command still will not silently crop an uncovered source cue.
3. **Grid, locks, and equality:** an uncovering ripple close in the SDK path must be frame-aligned (`NOT_ON_FRAME` is a refusal, not a pass). MoveClips follow does not invent a new caption-track lock; a locked *media* host still refuses the whole group as `FIELD_LOCKED`, and a locked caption track still refuses interval edits, matching already-delivered clipLocal behavior. `TimeRange` has no value `==`, so split/trim assertions compare start and duration. Official selected document+SDK+UI 166/0/0 (106+45+15) plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous marker-edit 152, caption-default 134, caption-interval 128, caption-follow 119, ignore-links 104, ripple-trim-lengthen 95, ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (auto-close as part of a move, new-track, cross-project, OS clipboard, 1000 NLE undo, field-aware inverse) or I-006, and they do not open source-interval crop or MP4 burn-in. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.38 — 1000 seeded random undos of already-opened NLE commands (three real reviews/corrections)

1. **Journal undo vs archive fork:** packing the 1000-edit journal together with save/restore caused a 30s restore timeout and a missing media symlink. The 1000 path now only edits, undoes, and redoes with a 10-minute test timeout; archive fork and sidecar/export live on a short one-command path. After a fork, IDs are remapped, so assertions compare text, kind, and time, not a whole-document hash.
2. **Marker order and snapshot purity:** MarkerStore orders by time, not insertion, so label lists must be keyed by id. `ProjectDocument.toJson` is a deep decode of the canonical string, so applyEdit cannot mutate the before document; the document suite asserts that start and before hashes stay equal after every success or refusal, including locked-host and negative-start cases.
3. **No silent source-cue loss, no new mode:** a random interval that would uncover a source cue must refuse rather than drop it. The driver never introduces auto-close-on-move, never burns captions or markers into MP4, and never changes delivered clipLocal / source / marker interval rules. Official selected document+SDK+UI 171/0/0 (108+47+16) plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel all exited 0; the previous source-anchor 166, marker-edit 152, caption-default 134, caption-interval 128, caption-follow 119, ignore-links 104, ripple-trim-lengthen 95, ripple-close 85, ripple-trim 75, ripple-delete 64, insert 51, overwrite 37, clipboard-only 7 and pointer-drag 281 are not mixed in.

These reviews do not close original I-005 (section-3 full matrix, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.39 — already-opened section-3 positive/negative matrix (three real reviews/corrections)

1. **Ripple remnant IDs:** closing R=[120,180) splits B at the range end; the left fragment is deleted and the surviving tail is a new id. Assertions look up that remnant by the table’s start, duration, and remapped source [90,210), not by the pre-edit id `s3-b`.
2. **Link offset and packed +1s:** the table’s 0.02s AV offset is off the 30 fps video grid; relink after that offset refuses OFF_FRAME_GRID. Packed A/B/C also cannot take the table’s +1s on A alone, because scaled A is 1s and would collide with B. The link example therefore uses an unsplit 3s pair and a one-frame (1/30 s) recorded offset, then includeLinks=false and unlink, without rewriting stored offsets.
3. **Adopt remaps IDs; preview is the collision UI:** ResourcePreservationSession adopt of planted source windows remaps `s3-b`/`s3-c`, so the SDK suite looks up clips by timeline. The workbench Commit button stays disabled until a valid ghost exists, so the colliding +6-frame move is qualified on Preview (COLLISION, no write) and then cancelled before the ripple-trim command. Official selected document+SDK+UI counts for this increment’s new files are 11+7+1; the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in. No new edit command, no new persistence table, no silent caption or marker drop, no MP4 burn-in.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse, caption-aware SplitClip/TrimClip, 0.02s off-grid link offset, marker sidecar formats) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.


## Increment1.40 — caption-aware SplitClip and leave-gap TrimClip (three real reviews/corrections)

1. **Absolute caption JSON:** turning a spanning or vacated cue into `{kind: absolute}` alone failed `SCHEMA_REQUIRED` at `/captions/0/anchor/clipId`. `_makeCaptionAbsolute` now writes the same `{kind: absolute, clipId: null, range: null}` object as `CaptionCue.toProjectJson`. Marker absolutes already used `{kind: absolute, clipId: null}`.
2. **Audio-path gate and linked members:** loosening only the generic caption gate left `_persistentAudioEdit` still throwing `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`, so a workbench split after extract looked like a no-op (the document did not change). The audio path now admits `SplitClip` and `TrimClip(ripple: false)` when captions exist; `MoveClip`, `SlipClip`, `DeleteClip`, and `TrimClip(ripple: true)` still refuse `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` rather than being rewritten as `LINKED_RIPPLE_NOT_IMPLEMENTED`. Leave-gap caption and marker helpers run for every linked member id, so a video-anchored cue is still cropped when the group is trimmed.
3. **Opened matrix and workbench revision:** section-3 tests that expected `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` for split and ordinary trim with captions were updated to the new positive geometry (a left cue stays `clipLocal`; leave-gap out keeps a covered cue and may leave an absolute remnant). The workbench path extracts through `extract-persistent-audio` so `_project.revision` stays in sync with the workspace. Ripple `TrimClip` with captions remains `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. Official selected document+SDK+UI counts for this increment’s suite are 129+57+18 (14 new: 10+3+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in. No silent caption or marker drop, no MP4 burn-in, no new persistence table.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse, caption-aware ripple TrimClip, 0.02s off-grid link offset, marker sidecar formats) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.41 — caption-aware ripple TrimClip (three real reviews/corrections)

1. **Stale sequence duration:** after the generic path had already extended sequence duration to the still-uncropped cue end, the interval hook cropped and shifted remnants to a shorter end, and `fromJson` failed `DURATION_MISMATCH`. Duration is now recomputed from media item ends and post-edit caption ends, not left at the pre-hook value.
2. **Remnant IDs differ:** comparing `TrimClip(ripple: true)` and `RippleTrimClip` remnants by id failed because the two commands allocate new cue ids from different `newId` sequences. Official assertions compare text, anchor kind, and timeline geometry.
3. **Linked audio stays refused:** the persistent-audio path still throws `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` for `TrimClip(ripple: true)` rather than falling through to `LINKED_RIPPLE_NOT_IMPLEMENTED`. Leave-gap `TrimClip(ripple: false)` still does not shift later cues. The workbench path imports video only so the Trim button issues ripple `TrimClip`. Official selected document+SDK+UI counts for this increment’s suite are 133+59+19 (7 new: 4+2+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 204, 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in. No silent caption or marker drop, no MP4 burn-in, no new persistence table.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse, linked-audio ripple trim, source-interval crop, 0.02s off-grid link offset, marker sidecar formats) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.42 — caption-aware linked-audio ripple TrimClip (three real reviews/corrections)

1. **Do not rewrite the refusal:** loosening only the persistent-audio caption gate would have let `TrimClip(ripple: true)` fall through to `LINKED_RIPPLE_NOT_IMPLEMENTED`. The audio path now delegates that command to the existing `RippleTrimClip` implementation (link closure plus the already-opened interval caption/marker hooks) so the command is applied, not recoded.
2. **Existing linked-trim fixtures:** `persistent_audio_test` and the SDK ripple shorten/lengthen suites expected `LINKED_RIPPLE_NOT_IMPLEMENTED` for `TrimClip(ripple: true)`. They now apply the command, assert both members share the new duration or that sequence duration changes by the delta, and undo back to the baseline so later SQL/fence checks still run on an unchanged document. The persistent-audio fixture already had a leave-gap in-trim, so the expected right-hand duration is measured from that state rather than assumed to be 2s − 1/2.
3. **Leave-gap and ripple delete stay refused as before:** `TrimClip(ripple: false)` still does not shift later cues; `MoveClip` with captions is still `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`; `DeleteClip(ripple: true)` is still `LINKED_RIPPLE_NOT_IMPLEMENTED` without captions and `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` with captions. The workbench path extracts persistent audio and uses the existing Ripple trim out control; the SDK persist path exercises `TrimClip(ripple: true)` itself. Official selected document+SDK+UI counts for this increment’s suite are 136+61+20 (6 new: 3+2+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 211, 204, 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in. No silent caption or marker drop, no MP4 burn-in, no new persistence table.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse, linked ripple delete, source-interval crop, 0.02s off-grid link offset, marker sidecar formats) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.43 — caption-aware ripple DeleteClip (three real reviews/corrections)

1. **Do not rewrite the refusal:** loosening only the persistent-audio caption gate would have let `DeleteClip(ripple: true)` fall through to `LINKED_RIPPLE_NOT_IMPLEMENTED`. The audio path now delegates that command to the existing `RippleDeleteClips` implementation (link closure plus the already-opened interval caption/marker hooks) so the command is applied, not recoded. The generic path also admits video-only ripple `DeleteClip` with the same interval hooks so that command is not left as `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` when no audio track exists.
2. **Existing linked-delete fixtures:** `persistent_audio_test` expected `LINKED_RIPPLE_NOT_IMPLEMENTED` for `DeleteClip(ripple: true)`, and the linked ripple-trim suite expected `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` when captions were present. They now apply the command on the ripple path (both members are removed and later content closes) and keep leave-gap `DeleteClip` plus `MoveClip` with captions as `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. Caption geometry is compared with `RippleDeleteClips` by text, anchor kind, and timeline range because remnant ids can differ.
3. **Leave-gap delete and MoveClip stay refused:** `DeleteClip(ripple: false)` with captions is still `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`; leave-gap `TrimClip` still does not shift later cues; `MoveClip` with captions is still `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. Source uncover is whole-group `ANCHOR_OUT_OF_RANGE`. Lifting a `clipLocal`-marker host is still `REF_NOT_FOUND`. The workbench path extracts persistent audio, splits at one second, and uses the existing Ripple delete range control; the SDK persist path exercises `DeleteClip(ripple: true)` itself. Official selected document+SDK+UI counts for this increment’s suite are 140+63+21 (7 new: 4+2+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 217, 211, 204, 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in. No silent caption or marker drop, no MP4 burn-in, no new persistence table.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse, leave-gap DeleteClip with captions, source-interval crop, 0.02s off-grid link offset, marker sidecar formats) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.44 — caption-aware leave-gap DeleteClip (three real reviews/corrections)

1. **Promotion of clipId:** a combined `is TrimClip || is DeleteClip` check widened the type back to `EditOperation`, so `operation.clipId` would not compile. The leave-gap snapshot now binds the clip id with a switch on `TrimClip(..., ripple: false)` and `DeleteClip(..., ripple: false)` before walking tracks.
2. **Do not reuse the trim remnant helper with an empty host:** `applyCaptionsAfterLeaveGapTrim` refuses `INVALID_RANGE` when `newEnd <= newStart`, and the post-trim hook skipped work when the host was already gone. Dedicated leave-gap delete helpers convert `clipLocal` cues and markers bound to the removed host into absolute remnants at the same times, without dropping text, and leave later content unmoved. Source uncover is still whole-group `ANCHOR_OUT_OF_RANGE` via `applySourceCaptionAbsolutes`.
3. **MoveClip and ripple delete stay as delivered:** `MoveClip` with captions is still `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`; `DeleteClip(ripple: true)` is unchanged from Increment 1.43. Lifting a `clipLocal`-marker host is still `REF_NOT_FOUND`; leave-gap delete of that host makes the marker absolute rather than dropping it. The workbench path extracts persistent audio, splits at one second, and uses the existing Delete (leave gap) control; the SDK persist path exercises `DeleteClip(ripple: false)` itself. Official selected document+SDK+UI counts for this increment’s suite are 144+65+22 (7 new: 4+2+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 224, 217, 211, 204, 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in. No silent caption or marker drop, no MP4 burn-in, no new persistence table.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse, source-interval crop, 0.02s off-grid link offset, marker sidecar formats) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.

## Increment1.45 — caption-aware MoveClip (three real reviews/corrections)

1. **Do not leave the generic path refused:** the persistent-audio caption gate was opened first, so linked `MoveClip` already followed cues while a video-only document still hit `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. The generic `applyEdit` gate now also admits `MoveClip`, and both paths reuse the already-opened `MoveClips` follow hooks (`applySourceCaptionAbsolutes`, `followClipLocalCaptions`, `applyClipLocalMarkerLocals`).
2. **Source gap stays a gap:** `MoveClip` only translates the selected clip (and its link members). It does not close the vacated source, and it is not a new `MoveClips` auto-close mode. A destination that overlaps later content is still whole-group `COLLISION` and leaves the document unchanged. Absolute cues stay at authored times; a source-anchored cue reprojects when the source window still covers it.
3. **Lift and interval uncover stay refused:** lifting a `clipLocal`-marker host is still `REF_NOT_FOUND`; an interval that would uncover or crop a source window is still `ANCHOR_OUT_OF_RANGE`. The workbench path extracts persistent audio and uses the new Move control (15 frames from the existing frames field); the SDK persist path exercises `MoveClip` itself. Official selected document+SDK+UI counts for this increment’s suite are 148+67+23 (7 new: 4+2+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 231, 224, 217, 211, 204, 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in. No silent caption or marker drop, no MP4 burn-in, no new persistence table.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse, source-interval crop, 0.02s off-grid link offset, marker sidecar formats) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.


## Increment1.46 — caption-aware LiftClips (three real reviews/corrections)

1. **Keep the clipLocal-marker lift code explicit:** converting clipLocal cues to absolute remnants would otherwise let `ProjectDocument.fromJson` reach marker validation, where a missing clipLocal host can surface as `ANCHOR_OUT_OF_RANGE` (`requireWritableMarkers`) instead of the already-delivered `REF_NOT_FOUND`. `_liftClips` now refuses a lifted clipLocal-marker host up front as `REF_NOT_FOUND` and does not convert those markers to remnants (leave-gap `DeleteClip` already does that, and this slice does not change it).
2. **Source uncover uses the already-delivered code, not a dangling-host leftover:** a previous lift of a source-anchored host failed as `REF_NOT_FOUND` only because the host was already gone at admission. The post-lift hook now snapshots source absolutes before removal and applies `applySourceCaptionAbsolutes`, so an uncovered source cue is whole-group `ANCHOR_OUT_OF_RANGE`, matching leave-gap `DeleteClip`. This is an explicit alignment, not a silent recode of the still-closed marker lift.
3. **Captions stay off the clipboard package; the source stays a gap:** `LiftClips` still leaves legal gaps and does not auto-close. Remnants stay on the timeline at authored times; the internal clipboard payload does not grow a captions field, and paste after cut does not copy or move them. A first, longer workbench help blurb pushed the Markers panel far enough that `nle_random_undo_ui_test` could not hit `marker-label`; the Cut/lift bound is now a length-neutral replacement of the stale clipboard sentence, and the collision-mode paragraph is unchanged. The workbench path extracts persistent audio, splits, adds a clipLocal cue, and uses Cut selection; the SDK persist path exercises `cutSelection` (`LiftClips`). Official selected document+SDK+UI counts for this increment’s suite are 152+69+24 (7 new: 4+2+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 238, 231, 224, 217, 211, 204, 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in. No silent caption or marker drop, no MP4 burn-in, no new persistence table.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, field-aware inverse, source-interval crop, 0.02s off-grid link offset, marker sidecar formats) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.


## Increment1.47 — field-aware invert of a prior command (three real reviews/corrections)

1. **Put invert on the existing history extension, and bump definition versions correctly:** `invertCommand` / `listCommands` / `_invertCommand` were first drafted as top-level functions in the store part file, so they could not see `_db` / `_commit`. They now live on the `CommandHistory` extension. The first persist-path invert then failed as `IMMUTABLE_VERSION_CONFLICT` because a `SetCaptions` write set often lists only the added cue, while the sequence definition hash also includes captions. Invert now bumps every versioned entity whose clock-stripped content changed, and bumps the sequence when captions or markers change, using the same `entity_versions` max+1 allocator as ordinary edits.
2. **Write-set and conflict compares ignore concurrency clocks:** a first unit test used the pre-split document as the `SetCaptions` before-image, so the write set included the split geometry and conflicted with a later move of the right remnant. The before-image is the document immediately before that command. `fieldInvertConflicts` also compares clock-stripped values, so a later version-only bump of an otherwise unchanged entity does not refuse the invert.
3. **Keep the invert control compact and below Markers; do not promise a full invert matrix:** the workbench adds a dense command-id field and Invert button after the Markers panel and does not list every history row. An earlier placement next to Undo/Redo made `nle_random_undo_ui_test` miss `marker-label` in the official UI suite; moving the controls below Markers restored hit-testing without lengthening the help blurbs. Invert of the tip stays `UNDO_CONFLICT` (use Undo). Official InversePatch kind stays `restoreSnapshot`; linear undo/redo stay tip snapshot restores; no new table. Archive/fork may remint clip ids, so persist-path checks assert remnant times, not the pre-fork id. The official path inverts a later `SetCaptions` after an unrelated leave-gap `MoveClip`; invert after a followed `clipLocal` host move is `UNDO_CONFLICT`. Captions and markers are not burned into preview or MP4. Official selected document+SDK+UI counts for this increment’s suite are 156+71+25 (7 new: 4+2+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 245, 238, 231, 224, 217, 211, 204, 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, source-interval crop, 0.02s off-grid link offset, marker sidecar formats, a complete command-by-command invert matrix) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.


## Increment1.48 — caption-aware overwrite move and paste (three real reviews/corrections)

1. **Rebind after carve, and bump cue versions when only the local range changes:** the first persist-path overwrite failed as `IMMUTABLE_VERSION_CONFLICT` because `_bindCaptionToHost` treated same-host rebinds as unchanged even when `anchor.range` had to move after a remnant's start changed. The bind path now reallocates a cue version when the local range changes, matching other content writes. Destination cues uniquely covered by a remnant rebind; otherwise the whole cue or marker is kept as an absolute remnant with the same text and times. Later content is not shifted.
2. **Overlapping a followed cue with a dest remnant is a whole-group refusal:** an overwrite that would land a moving `clipLocal` cue on a dest remnant at the same times is `CAPTION_OVERLAP` and does not write a partial member or drop text. This is the already-open overlap policy, not a silent merge.
3. **Keep delivered refusals and a compact workbench path:** source-window uncover stays `ANCHOR_OUT_OF_RANGE` (this slice does not open source-interval crop). Lifting a `clipLocal`-marker host stays `REF_NOT_FOUND`. Captions still do not enter the internal clipboard. The workbench uses the existing Collision mode overwrite control and does not lengthen clipboard helper text (Increment 1.46 already hid `marker-label` that way). Overwrite-move dest cues that lose their host become absolute remnants rather than being rebound onto the arriving clips; overwrite paste may rebind a uniquely covered dest cue onto the pasted clip. Official selected document+SDK+UI counts for this increment’s suite are 161+73+26 (8 new: 5+2+1); the official selected suite also re-runs opened-command regressions plus analyzer, actual old-library, SIGKILL undo/redo and 100 opacity_cancel. Previous 252, 245, 238, 231, 224, 217, 211, 204, 190, 171, 166, 152, 134, 128, 119, 104, 95, 85, 75, 64, 51, 37, 7 and 281 counts are not mixed in.

These reviews do not close original I-005 (full section-3 matrix including roll/slip/slide, auto-close as part of a move, new-track, cross-project, OS clipboard, source-interval crop, 0.02s off-grid link offset, marker sidecar formats, a complete invert matrix) or I-006. They do not fix underrun, old-writer schema9 as a product qualification, GPU/physical/other-platform or RTC policy. Original 87 and XD10 remain separately counted.
