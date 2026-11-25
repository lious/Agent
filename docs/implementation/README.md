# 可运行本地视频开发切片

**不是完整视频编辑器，也未完成全部87项。** 已有真实双 Flutter 宿主与共享 Dart/C++：
素材导入 → 单轨 split/trim/slip 等 → SQLite 事务 → 含原件工程 ZIP 保存 → 关闭重开 →
安全 fork 恢复 → FFmpeg 软件 H264/MP4 导出。原件/数据库不上传，无模型或付费 API。

视频范围仍为 CFR Rec709 limited 8bit、1×、相同偶数尺寸 ≤2048；持久音频/AAC与真实本地服务试听见increment1.7。
有音轨输入需明确 video-only 确认；未知色彩、VFR、旋转、alpha 等不伪装成可导出。
原104文档不变；当前全部87项逐项保留原验收：25 partial、49 planned、13 blocked（验证资源）。
**整任务完成数为0**；blocked 不等于实现完成，尚有大量可继续的纯 Dart 工作。

当前操作入口见文末 **increment1.8**；v1.0–1.6及以下旧计数是历史切片，以task-status和最新summary为准。

原始规划：[工程文档](../studio/README.md) · [87项任务](../studio/tasks/work-items.md)

- [基础 ADR](../adr/0001-foundation-slice.md) · [本地视频范围/偏差 ADR 0002](../adr/0002-local-video-vertical-slice.md)
- [执行进度](task-status.json)
- [三轮实际自审记录](REVIEW.md)
- [开发机工具链](../../tools/spikes/toolchain/linux-dev.json)
- `evidence/` 是本分支真实运行记录，不是旧设计的 schema 模拟测试。

## v1.0历史保存与恢复增量

自动保存现在登记本机 SQLite checkpoint（空闲2秒/最长30秒/50次durable提交），
**不**自动打包素材或写云端；后台/切工程/关闭会立即请求本地 checkpoint。
UI 的 durable/checkpoint/explicit/target 状态来自持久回执，重开不丢失；可显式
保存本机恢复点、查看归档阶段、在发布前取消，并明确重新选择原路径后验证中断发布。
保存中 SDK 可继续提交编辑，归档回执仍只对应捕获的 revision，不回退 head。

详见 [ADR0003](../adr/0003-managed-checkpoints-and-local-save-recovery.md)。
本轮总计74个 Dart/Flutter 测试（0跳过，含新增11个保存/失败/虚拟时钟和5个崩溃测试，每阶段内部10次进程SIGKILL）、6个工具测试、3个CTest；双宿主各3次clean/release构建启动通过。完整退出草稿处理、
损坏数据库隔离恢复/日志压缩、物理断电/磁盘满及非Linux provider资格仍未完成。
新证据 `evidence/save-checkpoints/`；旧 local-video 证据是历史基线，不冒充本轮计数。

## 新增字幕/音频/多端同会话增量

原87项仍 **21 partial / 53 planned / 13 blocked / 0整项完成**。
新增用户范围单列：[版本增量](../addenda/multidevice-v1.md)、[10项XD任务](multidevice-status.json)。

* Native `Caption editor`：普通cue添加/手改/拆分/裁剪、SRT/VTT/静态ASS导入、SRT/VTT sidecar导出；SQLite版本/撤销/归档/fork真实保留。MP4文字渲染、丰富样式/字体和跨clip同步ripple未实现，显式拒绝而不静默丢失。
* 真实Dart CPU PCM混音/总线路由/automation/duck proposal已落地，但未接FFmpeg音频解码、设备时钟或AAC，不宣称可听音频导出。
* **可编辑Web宿主**：`cd apps/studio_web && flutter run -d chrome`。元数据/普通字幕用实际IndexedDB事务CAS持久化；不是只读展示，也不是完整Web媒体编辑器/SQLiteWASM资格。可下载项目JSON，不含素材传输。
* **同一Session算力调度协议基础**：原PlanGraph安全子集、能力/负载/模型库存过滤、SQLite lease/fence/heartbeat/cancel/结果outbox，以及两个真实Linux子进程执行固定免费CPU任务。Chrome也实际执行同一核心；尚未连接浏览器与native网络会话，不是物理多设备验收。
* 未启用任何远程endpoint；可信配对/可撤销授权/加密传输/断点素材互传、完整跨端运行时与真实物理设备验收仍待实现，不会默认云传素材或用付费中继。

本批实际通过：97个native Dart/Flutter测试 + 3个真实Chrome测试 = **100个Dart/Flutter测试**，0跳过；另6个Python工具测试、3个native CTest；50次SIGKILL是5个测试的内部实验，不伪报成50个独立case。Web release JS构建通过；双Linux宿主各3次clean/release构建启动通过。

工具链：Flutter3.50.1 / Dart3.14.0（官方固定SDK），预装Chrome156.0.8078.47；系统SQLite3.46.1仅为DEV证据，**不满足原3.51.3+/经核验backport的生产WAL门禁**。未启用生产发布。

新证据以 `evidence/caption-audio-harness/` 为准；原结果保留为历史。

## 固定开发工具链

Flutter **3.50.1 stable** / Dart **3.14.0**；`.flutter-version` 仅登记，不自动安装。
官方来源：https://docs.flutter.dev/install/archive

```sh
curl -fL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.50.1-stable.tar.xz -o /tmp/flutter.tar.xz
echo '4ad17fc8462fbcef2ba19ff4a78c0a16b7147fde1add8578e267ea62cdb92678  /tmp/flutter.tar.xz' | sha256sum -c -
# 解压到自己的工具链目录，将 flutter/bin 加入 PATH。
# Debian/Ubuntu 原生构建依赖（会安装软件）：
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libsqlite3-dev g++ xvfb xauth
flutter --disable-analytics
flutter pub get --enforce-lockfile
```

只有开发 SDK/编译依赖，没有模型权重。依赖版本与哈希在根 pubspec.lock 中；
未声称其他 Flutter/Dart 版本验证通过。当前 sqlite3 2.x 适配器动态加载经严格门禁的
SQLite3.54.1（启动/测试前设置LD_LIBRARY_PATH，见v1.1/v1.2命令）；系统3.46.1不合格且默认拒绝。
不是已打包验证的iOS/Android/Windows插件；这些平台需另接可信库和门禁。

## 构建真实 native adapter / 启动

在上述基础依赖外，当前开发机实际链接 FFmpeg 7.1.x（不是旧 FFmpegKit binary）：

```sh
sudo apt-get install libavformat-dev libavcodec-dev libavutil-dev libswscale-dev nlohmann-json3-dev libswresample-dev libpulse-dev pulseaudio pulseaudio-utils ffmpeg
# 必须检查 pkg-config；Ubuntu24.04 默认 FFmpeg6.1 不等同这里已验证的 7.1 开发机。
pkg-config --modversion libavformat libavcodec libavutil libswscale
cmake -S native/studio_media -B /tmp/studio-media-native -G Ninja
cmake --build /tmp/studio-media-native
ctest --test-dir /tmp/studio-media-native --output-on-failure

export STUDIO_MEDIA_LIBRARY=/tmp/studio-media-native/libstudio_media.so
export STUDIO_DEMO_DATA_DIR=/自己的稳定开发目录
cd apps/studio_demo  # 或 apps/image_demo
flutter run -d linux
```

不设置 STUDIO_MEDIA_LIBRARY 时只打开 metadata UI，明确显示 adapter 未安装；
不自动下载 native binary。默认数据库在系统临时目录 studio-foundation-demo，可能被清理；
稳定目录需自行明确设置。两 App 各自 SQLite / namespace CAS，不访问旧 Mac 工程。

在 UI 手动输入本地视频路径 → Import → 选择 clip → split/trim/delete/undo →
输入归档路径保存 → Restore as fork → 输入 MP4 输出路径导出。仅源缩略图预览，非完整时间线播放；无原生音频混音；普通字幕可展开 Caption editor 编辑并导出SRT/VTT sidecar。
归档和 MP4 输出会在成功校验后原子替换所选目标；不得将其指向原始素材或其他重要文件。
已拒绝当前 CAS/数据库/本会话选过的原件，但尚无跨会话 host FileRegistry 误覆盖保护。

## 可复跑验收（从仓库根）

```sh
# 一条命令：造合成片、编译/CTest、Dart事务/编辑、Flutter真实媒体控件、工具测试、文档校验
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build /tmp/studio-media-native --report artifacts/local-video/verification.json
# 同一受限 suite 可从实际受影响任务的入口运行；不是整项验收完成声明：
python3 tools/acceptance/run_task.py I-024 --profile linux-dev --report artifacts/acceptance/I-024.json
# 原工具链资格探针：每宿主3次 clean/release build/Xvfb首帧 + 3次独立C ABI probe
python3 tools/spikes/toolchain/run_probe.py --profile linux-dev --report artifacts/acceptance/V-001.json
```

run_local_video 强制设置真实 native library 与合成媒体 fixture，跳过任何媒体/widget 测试则失败。
报告记录命令、退出码、工具版本、源文件 SHA、非 hidden/非 skipped 测试数，始终
fullTaskComplete:false。原 I001-I003 foundation 入口仍保留；单独运行 SDK 测试未设置 native
变量会 skip 媒体测试，不得以此冒充媒体验证。Widget 测试需从所属 package 执行以打包 shader。

当前证据见 evidence/local-video/；389bd52历史基线共有 58 个 Dart/Flutter 测试（包含1000 seeded
领域 cases 与1000次真实 SQLite edit/undo，不将内部循环伪报成独立测试数），6个工具测试，
3个 native CTest cases（100个双namespace开关轮次、10次native cancel、fd增量0），另有
ASan/UBSan/LSan 的相同3 cases。最终准确计数以 verification.json 为准。

可保留实际演示成片（需要 suite 产生的3秒 fixture 和全新工作目录；会替换指定 output）：

```sh
dart run packages/studio_sdk/tool/local_video_demo.dart /tmp/studio-media-native/libstudio_media.so artifacts/local-video/input.mp4 artifacts/local-video/new-demo artifacts/local-video/demo.mp4
ffprobe -v error -count_frames -show_entries stream=codec_name,nb_read_frames,duration,width,height -of json artifacts/local-video/demo.mp4
```

此演示生产 Dart/C++ 路径导出 320×180、45帧、1.5秒 H264，并保留真实工程包和数据库。
没有把旧 Schema 模拟测试当成 App/媒体测试。CLI 只接受宿主明确选择的路径，不能暴露给模型工具。

CI 配方 docs/implementation/foundation-ci.yml 仍为 **不执行的 foundation-only 配方**。
GitHub OAuth 缺 workflow scope，未提权/绕过，没有启用 .github/workflows 或声称远端 CI 通过。
当前 FFmpeg 系统配置含 GPL libx264，未完成源码锁定/SBOM/再分发审查；许可 unknown 只警告，
不伪造授权。真机/其他平台/模型/付费 API/生产发布未运行。

## Chrome 与新增协议验收

```sh
# 实际安装的Chrome，不使用模拟transport；无自动浏览器/模型下载
export CHROME_EXECUTABLE=/你的Chrome可执行文件
python3 tools/acceptance/run_multidevice_dev.py --report artifacts/acceptance/multidevice-dev.json
# 云端root测试包装脚本仅对合成fixture用 --no-sandbox，不作为生产启动设置。
```

此入口实际跑 Chrome IndexedDB/Flutter 与 release Web build，永远
`physicalDeviceQualification:false`。各平台分别验收；macOS/Windows/iOS/Android 未测，
不因Linux/Chrome通过而标支持完成。网络配对/转发/模型/素材上传/付费服务均未启用。

## 代码地图

| 包/目录 | 已实现 |
| --- | --- |
| studio_contracts | AppProfile、namespace、稳定错误码、ID |
| studio_document | BigInt 有理时间/帧/sample/区间；2.0 文档值、工厂、部分 validator、JCS hash |
| studio_store | SQLite v1→v2→v3→v4；revision/CAS/fence/receipt/outbox/历史定义与blob pins；最新快照撤销；CAS原件；受限ZIP归档/fork；Linux原子发布 |
| studio_harness | scoped SessionRef 与 ProposalPort 契约；没有可执行 Agent |
| studio_media / native/studio_media | Dart FFI与实际C++20 libav probe/decode/软件H264/MP4、取消与能力事实 |
| studio_sdk | 同一装配/事务入口，真实导入、编辑、保存、恢复、冻结快照导出 |
| studio_editor_ui | 两宿主共享的真实 metadata 与 local-video 操作 UI |
| apps/* | AppProfile、明确安装的 native library、开发数据路径与 Linux runner |
| tools/acceptance | 实际非跳过媒体suite与逐项受限入口；不会改写原规划验收 |

## 尚未完成 / 下一批（持续授权，不需逐批审阅）

优先 I-010 字幕、I-009 音频语义、I-012 autosave/save serialization、I-011 崩溃点与恢复扫描，
再接 I-021 seek/cache、I-023真实音频执行、I-024 AAC/音画同步与60秒资格。
并继续所有无外部条件阻塞的87项依赖就绪任务；详细每项仍欠缺的原验收在 task-status.json。
没有自动 merge 功能分支、force/rebase 已推历史、访问 Mac、下载模型或部署。

## Native authenticated peer + SQLite source correction

Latest increment adds `packages/studio_peer_io`: an actual native mTLS HTTPS endpoint and real same-session child worker, backed by original PlanGraph/SQLite lease/outbox state, scoped expiring offline-confirmed grants, durable request receipts, revocation on keepalive/replay, pinned input/output schema/hash/source, one-heavy-slot admission and LOCAL owner boot takeover/quarantine. No peer can register plans, pair itself, grant permissions, run shell/model/provider work or write a project revision. Default bind is loopback; LAN bind requires explicit host selection/enablement. No production service is deployed. See ADR0005 for the exact security boundary.

This is an SDK/maintainer development path, NOT yet an App pairing UI or OS key-store integration. The worker PEM CLI is exclusively for synthetic temporary test identities. Browser editing remains real, but native mTLS is not advertised as browser/mobile transport; no physical-device qualification has happened.

### Reproduction (Linux only)

Official Debian prerequisites: `cmake ninja-build pkg-config clang libgtk-3-dev libavformat-dev libavcodec-dev libavutil-dev libswscale-dev nlohmann-json3-dev`; OpenSSL, FFmpeg, Xvfb and Chrome are also required by their real tests. Use the already pinned official Flutter/Dart SDK from the earlier toolchain section.

```
python3 tools/bootstrap_sqlite.py --directory /workspace/toolchains/sqlite-3.54.1
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
flutter pub get
dart test packages/studio_peer_io/test packages/studio_store/test/harness_takeover_test.dart --reporter expanded
python3 tools/acceptance/verify_sqlite_upgrade.py --library-dir /workspace/toolchains/sqlite-3.54.1 --report artifacts/local-video/sqlite-upgrade.json
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build /workspace/agent-media-native-peer --report artifacts/local-video/peer-verification.json
CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test python3 tools/acceptance/run_multidevice_dev.py --report artifacts/local-video/peer-browser.json
python3 tools/spikes/toolchain/run_probe.py --profile linux-dev --report artifacts/local-video/peer-V-001.json
```

Repository runtime now defaults to exact approved SQLite3.54.1 SOURCE_ID + THREADSAFE=1 before migrations; explicit `allowUnqualifiedSqliteForDevelopment` is NOT a qualification result. Old historical system3.46.1 reports remain DEV and are not rewritten. Real original-v4-code/system-SQLite -> current-v5/fixed-SQLite migration preserves project content and active lease cutoff; current code refuses old runtime. This fixes the Linux source/version gate, not every production/WAL/power-loss/platform gate. Never share a live WAL database across machines or run old/new runtimes concurrently against it.

Evidence: `evidence/peer-tls-sqlite/`. Original87 and newXD10 remain independent; original I-003 local concurrency/undo/fault/isolation acceptance has been rechecked, but complete upstream Schema and the wider originals are still missing. Do not promote whole tasks merely because a bounded integration test passed.

v1.1历史增量最终实际结果：**115个Dart/Flutter测试（112 native + 3真实Chrome），零跳过**；另6个Python工具测试、3个native CTest，50次SIGKILL为内部实验；双Linux宿主各3次clean/release构建启动通过。Web release JS编译通过，不冒充release页面运行/其他浏览器/物理多设备。实际加载SQLite3.54.1精确SOURCE_ID、THREADSAFE=1；系统pkg-config仍报3.46.1，未替换系统库且它仍不合格。工具链Flutter3.50.1 / Dart3.14.0，Chrome156.0.8078.47，fixture证书工具OpenSSL3.5.9。该历史版本报告与当时代码sourceHashes匹配；当前版本以v1.2证据为准。


## v1.2 当前可操作增量：Linux OS身份 / 显式配对 / 同会话计算 / 受限文件传输

[ADR0006](../adr/0006-linux-os-identity-and-bounded-peer-inbox.md) ·
[新证据](evidence/peer-ui-blob/summary.json)。不是只有SDK接口；两个native宿主都接入真实面板。

1. 在Linux安全存储服务可用的桌面启动native App，展开 **Trusted peer session · Linux preview**。
   默认不监听/不自动生成身份。先选择身份IP（默认127.0.0.1用于本机协议实验；LAN需先选实际IP），
   点 **Create/load OS-stored device identity**。密钥进入libsecret，不能输出私钥/将其放入工程包。
2. 双方通过独立可信通道核对**完整**证书SHA256；复制公开offer给owner，不能只照抄不验证。
   需要发文件时worker先选本机文件并点 **Freeze selected file + offer public hash/size**，
   它仅冻结<=16MiB精确字节并发布hash/size，路径和文件均尚未传输。把此更新offer给owner。
3. Owner粘贴worker公开offer、键入其独立确认指纹、显式勾选元数据同意；需要文件再单独勾选blob同意。
   LAN还须单独开启LAN监听。点 **Approve peer + start scoped session**（一peer、一node、10分钟grant）。
4. Worker粘贴owner邀请，独立确认owner完整指纹、勾选元数据同意，点 **Run invited task on this device**。
   这是实际免费元数据CPU任务；owner点 **Run other node locally in the SAME session**，
   两个任务属于同一个原PlanGraph，不改Project revision，不是两个fork冒充协作。
5. Worker点 **Send/resume exact granted blob to paired device**，实际TLS分块并恢复缺失块；owner仅收到
   校验inbox，不自动导入项目/模型/云端。SDK `receivedPeerBlob`可本机读并再次校验；当前没有inbox浏览/GC/项目采纳UI。
6. Owner可刷新持久回执或 **Revoke peer and stop listener**；旧grant/缓存回执不可绕过撤销。
   再显式配对得到新session，不复活旧权限。App重启不会自动恢复授权/监听。
   多session本地执行共享同一namespace逻辑slot，不能换session ID绕资源门禁；进程崩溃留下的
   running slot需显式trusted-local恢复，当前没有自动恢复权限或完整重启管理UI。

只资格验证Linux OS store；非硬件不可导出密钥，私钥会在进程内存中存在。证书固定首次选择IP，
无轮换UI。UI目前一owner+一peer、两小型元数据digest，不是任意N端或模型/FFmpeg分布式执行。
64MiB是逻辑stage预约限额而非物理磁盘上限（chunks/objects重复，约128MiB载荷+WAL/索引等）；
无GC，不接受对端路径。完整项目CAS采纳/大文件、Web加密transport、移动/其他桌面/物理多端仍未完成。
**Web不是native mTLS**；现有Web编辑/IndexedDB继续可用，但未添加不安全匿名socket或绕过证书认证。

### 本增量真实复跑（Linux box，Asia/Shanghai）

前置：官方Flutter/Dart与原native FFmpeg依赖，官方Debian `libsecret-1-dev`、
`gnome-keyring`、`dbus-x11`。新增依赖锁定`flutter_secure_storage`11.2.0/Linux插件3.0.3。
测试runner使用全新隔离D-Bus/HOME/XDG keyring和内存生成的测试密码，不读取/解锁既有用户keyring。

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
python3 tools/acceptance/run_peer_ui.py --report artifacts/local-video/ui-blob-native-ui-verified.json
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build /workspace/agent-media-native-peer --report artifacts/local-video/ui-blob-verification.json
CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test python3 tools/acceptance/run_multidevice_dev.py --report artifacts/local-video/ui-blob-browser.json
python3 tools/acceptance/verify_sqlite_upgrade.py --library-dir /workspace/toolchains/sqlite-3.54.1 --report artifacts/local-video/ui-blob-upgrade-v4.json
python3 tools/acceptance/verify_sqlite_upgrade.py --library-dir /workspace/toolchains/sqlite-3.54.1 --baseline-commit 85b9b49d9d9cd4e2b5562e1d7b416c0d48ae52d0 --baseline-schema 5 --baseline-library-dir /workspace/toolchains/sqlite-3.54.1 --report artifacts/local-video/ui-blob-upgrade-v5.json
python3 tools/spikes/toolchain/run_probe.py --profile linux-dev --report artifacts/local-video/ui-blob-V-001.json
```

不要让toolchain probe的flutter clean和native integration build同时操作同一个App。
以上使用校验过的SQLite3.54.1，不覆盖系统3.46.1，后者仍被默认门禁拒绝。没有OAuth/workflow权限变更。
真实版本/测试计数/未验范围见本增量summary；历史证据不是本轮测试，也不把同机双pane/TLS/Chrome当物理设备通过。

`foundation-ci.yml`仅更新为当前SQLite/keyring/peer子范围的**未安装配方**，未上传为active workflow、未远端执行；完整native媒体仍以真实本地gate为准。

本增量最终实际结果：**119个Dart/Flutter测试（115 native回归 + 3真实Chrome + 1真实OS keyring/native UI），零跳过**；另6工具测试、3 CTest、内部50次SIGKILL；双Linux宿主各3次clean/release构建启动。真实v4/v5→v6迁移均通过、旧SQLite默认拒绝。最终sourceHashes与交付代码一致。原87仍0 complete /21 partial /53 planned /13 blocked；新增XD10为0 complete /8 partial /1 planned /1 blocked，未缩减原验收。


## v1.3 当前可操作增量：显式同会话恢复 / 收到视频采纳 / 历史pin安全GC

[ADR0007](../adr/0007-explicit-session-recovery-and-controlled-cas-adoption.md) ·
[本轮证据](evidence/recovery-adoption/summary.json)。上述v1.2“无恢复UI/无采纳GC”是历史边界。

* **App重开恢复**：在同一个稳定`STUDIO_DEMO_DATA_DIR`重开Linux宿主，加载同一OS身份；
  展开peer面板，点 **List saved SAME-session recovery choices**，核对所选session JSON，单独勾选恢复同意再
  点 **Recover chosen SAME session (no peer renewal)**。原session/plan/input/result保留，
  原peer/metadata/blob权限、监听不恢复，旧endpoint即使尚未退出也不可用旧授权；重新联网需再次配对同意。
  同Linux OS boot用真实内核时钟计入离线/暂停时间，换OS boot/未知时钟不免费重置预算；
  真实OS重启/暂停及非Linux时钟未资格验证。当前仍仅两小型metadata digest，不是通用模型/视频分布式执行。
* **收到素材加入工程**：peer独立授权传输后，在原native媒体页填 **Received peer inbox raw SHA256 to explicitly adopt as video (no path)**
  （原始64位hex），点显式采纳按钮。它实际校验inbox/CAS、native FFmpeg probe、原编辑事务，
  与本地导入同样限制silent CFR/色彩/尺寸，音轨须video-only明确同意。重复点击同一intent不会重复
  添加；如要再次添加同素材需显式新intent。随后可split/trim/undo、保存工程包、关闭重开并导出真实MP4。
  SDK真实TLS->CAS->归档/重开->90帧无声导出已测；采纳/GC控件尚无独立点击式UI全程资格测试。
* **显式清理**：单独勾选清理同意、运行本机清理；只清无任何历史blob_edges引用的规范CAS文件
  （每次最多1000）和撤销/过期/旧epoch inbox；不删原件、不裁历史、不删活动grant的数据。
  支持的导入/采纳/restore与GC共用稳定进程间advisory锁+owner-isolate队列，SQLite writer事务保住pin快照。
  当前App只有一个发布/GC owner isolate，不能把POSIX进程锁误当跨isolate互斥；多独立发布isolate未资格验证/不支持。
  SQL触发器故障回滚与采纳/GC重叠有真实回归；文件删除不是全局可回滚事务，且不承诺SQLite文件缩小，
  64MiB仍是逻辑预约而非物理磁盘上限。不要手动删除`.cas-maintenance.lock`。

本轮复跑（根目录，前置工具/OS keyring同v1.2）：

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build /workspace/agent-media-native-peer --report artifacts/local-video/recovery-verification.json
CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test python3 tools/acceptance/run_multidevice_dev.py --report artifacts/local-video/recovery-browser.json
python3 tools/acceptance/run_peer_ui.py --report artifacts/local-video/recovery-ui-final.json
python3 tools/acceptance/verify_sqlite_upgrade.py --library-dir /workspace/toolchains/sqlite-3.54.1 --report artifacts/local-video/recovery-upgrade-v4.json
python3 tools/acceptance/verify_sqlite_upgrade.py --library-dir /workspace/toolchains/sqlite-3.54.1 --baseline-commit 85b9b49d9d9cd4e2b5562e1d7b416c0d48ae52d0 --baseline-schema 5 --baseline-library-dir /workspace/toolchains/sqlite-3.54.1 --report artifacts/local-video/recovery-upgrade-v5.json
python3 tools/acceptance/verify_sqlite_upgrade.py --library-dir /workspace/toolchains/sqlite-3.54.1 --baseline-commit f843d6b066ba426755fb46bf5a4f0d1e9dbfe75a --baseline-schema 6 --baseline-library-dir /workspace/toolchains/sqlite-3.54.1 --report artifacts/local-video/recovery-upgrade-v6.json
# 不得和上面native UI build同时flutter clean：
python3 tools/spikes/toolchain/run_probe.py --profile linux-dev --report artifacts/local-video/recovery-V-001.json
```

**v1.3历史状态，已被下方v1.4覆盖**：Web现有编辑/IndexedDB照常；当时Web安全transport仍待实现，不宣称当时存在外部blocked。
已核实WebRTC可持久RTCCertificate/独立确认SHA256+DTLS；仍需实际transport、native互通和
持久scope/revocation/原scheduler receipts接通。未弱化配对、没有默认STUN/TURN/云端或付费中继。
物理设备/LAN/NAT、iOS/Android/macOS/Windows、浏览器peer、模型/原生音频AAC/seek/cache/full Schema
均不能用本轮Linux/Chrome协议集成代替。原87与新增XD10统计仍分别保留，完整验收没有一项冒充完成。


v1.3最终实际结果：**127个Dart/Flutter测试（123 native回归 +3真实Chrome +1真实OS keyring/native UI），零跳过**；
另6工具测试、3 CTest、5个测试内部50次SIGKILL；双Linux宿主各3次clean/release构建与首帧启动、
3次独立ABI clean probe。实际v4/v5/v6→v7迁移、严格3.54.1 SOURCE_ID/THREADSAFE与旧runtime拒绝通过。
保留三个真实失败后修正的安全回归（foreign-boot quarantine、session/boot复用、stale admin权限），
13项focused重跑是native suite子集，不额外加计数。工具链Flutter3.50.1/Dart3.14.0、Chrome156.0.8078.47。
原87仍0 complete /21 partial /53 planned /13 blocked；新增XD10仍0 complete /8 partial /1 planned /1 blocked。
本轮闭合上面明确的受限操作路径，而不是任何完整原任务；后续不因本批提交等待逐批确认。


## v1.4 当前可操作增量 — Web身份/原Harness适配与indexed源缩略图

[ADR0008](../adr/0008-web-rtc-identity-and-indexed-source-preview.md) ·
[版本规格增量](../addenda/multidevice-v1.4-web-rtc.md) ·
[本轮证据](evidence/web-rtc-seek/summary.json)。历史计数不是本轮结果。

- Linux编辑器：导入受支持视频→选clip→`Source thumbnail time ms`输入源时间→
  `Seek selected source + show thumbnail`，显示真实FFmpeg解码RGBA缩略图；编辑后旧图清除。
  源时间以第一PTS为0，不是timeline/effect播放。128边长、2MiB像素LRU、256项上限。
- Web：`cd apps/studio_web && flutter run -d chrome`，主动展开
  `Trusted direct WebRTC session`→加载持久浏览器证书→独立确认对方全SHA256→明确metadata同意→
  手动Offer/Answer。没有自动信令/云传/中继。**当前受管Chrome候选为0，实际会关闭并显示
  RTC_DIRECT_CANDIDATES_UNAVAILABLE；未跑通Web加密任务会话**，不能承诺可连接。
- 可真实点击Owner本机第二节点、读取原Harness持久回执、撤销；重开同一浏览器身份可查看
  只读历史，不自动恢复coordinator/权限。该本机路径不能冒充remote网络协作。
- 原native libsecret/mTLS/受限断点blob/同会话恢复/显式CAS采纳路径保留；本轮回归而非重造。
  未接browser↔native bridge、browser worker结果outbox/reconnect或Web blob传输。

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
# 自己机器需按固定官方工具链/SQLite安装说明选择实际目录，不得用系统3.46.1冒充。
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build /tmp/studio-media-native --report artifacts/local-video/current.json
CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test python3 tools/acceptance/run_multidevice_dev.py --report artifacts/local-video/browser-current.json
# 正向资格独立运行：当前环境返回2=blocked，绝不是pass。无mock/skip/策略修改。
CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test python3 tools/acceptance/run_web_rtc_qualification.py --report artifacts/local-video/rtc-positive.json
```

所有原87任务仍0 complete /21 partial /53 planned /13 blocked；新增XD10仍
0 complete /8 partial /1 planned /1 blocked。I-021按原四条验收逐条留下**受限源预览证据**，
代理映射/完整preview/原P0设备与clock/load未完成，不能据此改成complete。真实音频解码/
可听AudioSink/AAC、完整Schema和其他原任务继续待开发，不以本批Web阻塞停全部。
没有物理多设备、macOS/Windows/iOS/Android或模型/付费服务验收结果。

本轮最终真实结果：**125 native +9 Chrome +1 OS-keyring/native UI =135 Dart/Flutter测试**，
0跳过；6个工具测试、3个CTest、50次内部SIGKILL（不额外计case），双宿主各3次
clean/release构建和首帧启动均通过；Web release JS构建通过。SQLite3.54.1严格门禁，
v4/v5/v6真实历史数据库→v7迁移与旧runtime默认拒绝保留并重新执行。
正向WebRTC资格实际退出1，外层runner返回2=blocked；不计入135个通过case。
完整命令/版本/失败记录/源hash及所有限制见本轮summary，不把模拟transport或同机Chrome
当作物理协作验收，不把源缩略图当作完整预览/AAC。

## v1.5 当前可操作增量 — 真实离线音频→Dart AudioBus→AAC/MP4

[ADR0009](../adr/0009-bounded-offline-audio-and-aac.md) ·
[本轮真实证据/计数/限制](evidence/audio-aac/summary.json)。上方v1.0–v1.4计数与
“尚无AAC”等描述是对应历史版本，不是本版状态；原始104规格没有覆盖修改。

Linux运行入口（这里的路径是本云端环境；自己的机器需安装批准工具链并替换路径）：

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
cmake -S native/studio_media -B /tmp/studio-media-native -G Ninja
cmake --build /tmp/studio-media-native
export STUDIO_MEDIA_LIBRARY=/tmp/studio-media-native/libstudio_media.so
cd apps/studio_demo
flutter run -d linux
```

- 选含嵌入音轨的受支持SDR CFR视频；明确勾选“Create a video clip only…”后导入。
  该确认只创建视频clip，原素材的音频字节仍在本地CAS，不是一个AudioClip链接。
- 可选clip、源缩略图seek、split/trim/undo；输入master gain（-96..12dB）并保存，
  或master mute。这些设置走原revision/CAS/undo/SQLite和归档，不是仅控件本地变量。
- 显式保存归档、恢复fork/关闭重开保留master设置；在**本次导出**勾选
  “Explicitly include embedded audio…”才会走真实AAC路径。该临时选择不会写进工程，
  不偷偷把历史视频clip变成持久音视频链接。默认仍可导出无声视频。
- 输出实际H264 Main4/8bit420 + AAC LC48k stereo MP4；内部使用成熟FFmpeg API和
  原Dart AudioBus，不调用FFmpeg CLI、不用Python替代引擎。文件先校验/hash，后原子发布。
- 当前音频离线导出<=120秒、<=128段、有界600秒源解码历史；仅master无效果子集，
  不支持的声道/格式/时间戳/资源量会明确报错，不隐式重采样策略或云端降级。
  原有HDR/VFR导出、字幕渲染、效果/缩放等未实现门禁仍保留。
- **没有**可听timeline播放、AudioSink已呈现sample时钟/ring/设备切换、音频独立clip/
  link-group/自动duck/full RenderGraph。这些原验收仍未完成；离线同步不是设备播放同步。

真实独立验收入口（仅在checkout根目录）：

```sh
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build "$STUDIO_NATIVE_BUILD" --report artifacts/audio-native.json
python3 tools/acceptance/run_audio_qualification.py --native-library "$STUDIO_MEDIA_LIBRARY" --report artifacts/audio-60s.json
# 原任务入口也会执行native回归，随后实际60s资格；不会将整项标complete。
python3 tools/acceptance/run_task.py I-023 --profile linux-dev --report artifacts/I-023.json
```

`STUDIO_NATIVE_BUILD`需设为实际checkout外构建目录。测试用CLI生成合成素材和独立测量；
没有提交媒体二进制、用户素材、私钥或模型。codec-only SPDX inventory只是实测动态库/许可证
事实，不是完整App/transitive release SBOM或再分发授权；GPL/libx264限制仍需发布前核查。

原87与新增XD10状态始终分开，完整任务完成不因本版受限用户路径闭合而虚增；实际结果、
全状态、失败证据和下一步见summary/task-status。物理多设备与macOS/Windows/iOS/Android
未验证；Web正向RTC仍受原受管0候选策略阻塞，不改策略、不走替代transport/中继绕过。

本版最终实测：**128 native +9 Chrome +1真实OS-keyring/native UI =138个Dart/Flutter测试，零跳过**；另6工具测试、3 CTest、10主动AAC+10无声视频取消内部实验、50次内部SIGKILL。双宿主各3次clean/release构建及首帧启动、3次独立ABI probe通过。实际60秒1080p30输出1800帧/2880000逻辑音频samples，60个合成flash/pulse事件测得最大阈值起点偏差0ms（仅离线文件，不是设备时钟）。原87：**0 complete /22 partial /52 planned /13 blocked**；新增XD10：**0 /8 /1 /1**。正向RTC重跑仍实际退出1、外层runner2=blocked，不计通过。所有工具链/测量方法/失败/源hash见summary。

## Increment1.6: persistent audio Clips and semantic closure (Linux restricted slice)

Use the existing pinned toolchain/native library and approved SQLite3.54.1 environment below; never accept the system3.46.1 runtime:

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
```

In either Linux demo editor: import a supported audio-bearing video with the existing explicit import acknowledgment; select its video clip; click **extract persistent audio** (one audio stream in this UI; ambiguous streams refuse). The new separate audio clip is linked and durable. Split/trim/move/slip/delete have linked domain semantics; the UI trim/delete explicitly leave a gap rather than claiming ripple support. Track mute and unlink are real persisted controls. Save archive, restore/fork, or close/reopen: the audio clips/link groups remain. Export normally: AAC is included **without** the old transient checkbox. The old checkbox is disabled when persistent audio clips exist, and the SDK explicitly rejects requesting both modes.

Actual UI coverage clicks import→source seek→extract→linked split/trim/undo→gain→archive/fork→track mute/unmute→unlink→default AAC export. SDK coverage independently decodes output to measure audible/silent samples, reopens SQLite and verifies default AAC export, duplicate-mode refusal, frozen revision and cancellation. Domain tests include1000 exact trim/inverse operations, origin offsets, locks/source/id failure paths, and a rich image/story/plugin roundtrip. SQLite tests inject a failure after definitions/pins, inspect every table, retry/dedup, stale CAS, undo, reopen and retired audio-ID version reuse.

**Not timeline listening:** no AudioSink/presented-clock/ring/playback/device rebind implementation yet. Unsupported linked ripple/roll/slide, caption reprojection, fractional-grid combinations, independent audio import and full Schema app editing remain explicit refusals/unfinished work. The60s test remains offline file sync, not device latency. See ADR0010 and `evidence/persistent-audio/summary.json` for exact results, failures and platform limits. Original87 and XD10 statuses are not inferred from test totals.

## Increment1.7 — real local-service audio timeline audition

After importing supported audio-bearing video and **extract persistent audio**, both
Linux editors now provide **Play audio timeline / Pause / Resume / Stop**, exact48k
seek (milliseconds), and explicit sink rebind. Blank sink uses the local service's
default device; an explicit local Pulse sink name can be entered. **Rebind starts
paused**: inspect the new clock epoch before Resume. Edits stop an old frozen
snapshot; backgrounding pauses playback or cancels unfinished preparation, and
returning never auto-resumes. Save/reopen/archive/default-AAC paths are unchanged.

Use the same approved SQLite3.54.1 PATH/LD_LIBRARY_PATH above and build native with
libpulse-dev; local playback requires an existing OS-authenticated Pulse Unix
service (`PULSE_SERVER=unix:/absolute/path` or `$XDG_RUNTIME_DIR/pulse/native`).
No remote/default cloud fallback or audio daemon autospawn. The UI reports real
service-confirmed sample position, not elapsed wall time or submitted samples.
Underrun/device loss/stale timing freezes it; explicit seek/rebind creates an epoch.
An uncertain queued tail can replay on explicit recovery; no exactly-once claim.

**Bounds/limits:** pre-rendered audio-only <=120s/128regions, admitted one audio
track/master and1x. Not video timeline playback/full RenderGraph or PipeWire/mobile
qualification. Actual Pulse17 software monitor output is verified, **not physical
DAC/human hearing/60s presented AV sync**. Device-clock capability stays false.

```sh
# Full native gate now starts its own isolated real Pulse service; no skipped tests.
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build /workspace/agent-media-native-peer --report artifacts/local-video/audio-sink-native-final.json
# Actual software-service faults, monitor capture, ring/queue/resource bounds:
dbus-run-session -- python3 tools/acceptance/audio_sink/pulse_smoke.py
# Focused mandatory real-service SDK / widget cases; preserve fixture/library env:
python3 tools/acceptance/audio_sink/run_private.py dart test packages/studio_sdk/test/timeline_audio_test.dart
(cd packages/studio_editor_ui && python3 ../../tools/acceptance/audio_sink/run_private.py flutter test test/timeline_audio_ui_test.dart)
# Explicit unavailable adapter still builds without Pulse (not non-Linux evidence):
cmake -S native/studio_media -B /workspace/agent-media-native-no-pulse -G Ninja -DSTUDIO_ENABLE_PULSE=OFF
```

The software-service harness requires `pulseaudio`, `pulseaudio-utils` and
`dbus-run-session`. It isolates its temporary Unix socket/daemon, never alters the
box desktop's audio service, and does not claim physical devices. The SDK/widget
cases are mandatory (no service skip). libpulse17 install source is official Debian
apt; observed LGPL-2.1+ facts are not full App release license clearance.
See [ADR0011](../adr/0011-local-pulse-audio-audition.md),
`evidence/audio-sink/summary.json`, and REVIEW for exact runs/failures/limits.

本版最终来源绑定回归：162 native Dart/Flutter +9 Chrome +1真实OS-keyring UI = **172项**，零跳过；另6工具/3个CTest（Pulse开/关各执行）、6次Linux clean/release启动和3次独立最小ABI probe。原87：**0 complete /23 partial /51 planned /13 blocked**；XD10：**0 /8 /1 /1**。先前一次并行门禁真实underrun和一次点击UI超时保留在failures，不冒充V-004热负载通过。原104及原验收/依赖逐项保留。


## increment1.8 — 原始PTS代理与服务确认sample驱动的真实Linux影音预览

本批恢复中断现场，保留原全部变更和失败日志后完成实际修正；不是将上轮中断算作通过。
原87：**0 complete /25 partial /49 planned /13 blocked**；新增XD10仍单列为
**0 complete /8 partial /1 planned /1 blocked**。I-021/I-022/V-003仅下述范围partial，
GPU/P0/全资源生命周期与其他平台未验证，不能据测试数推导完整任务完成。

### 实际用户操作

1. 按上方固定Flutter/SQLite3.54.1与native库命令启动Linux `studio_demo` 或共享编辑器宿主。
2. 导入admitted CFR/SDR AV，明确确认视频策略并提取持久linked AudioClip。
3. 点击 **Build timeline video preview proxies**，完成后勾选timeline video。
4. Play/Pause/48k sample精确seek/Rebind/Resume/Stop；可见RawImage图像及真实服务sample、
   epoch、delivered/committed/stale/source-skipped/late诊断。16ms计时器仅请求，不生成媒体时钟。
5. 编辑后旧snapshot/stream/image失效；既有undo、SQLite/checkpoint、ZIP保存、fork/重开保留。
   代理仅本机临时资源，关闭清理，重开须显式重建，**不是已持久化SchemaProxy**。
6. 实际H264/MP4+默认持久音频AAC导出仍使用验证原件；与预览共用单轨精确源时间graph，
   不编码低清代理/截图。字幕渲染、非黑背景、尺寸/像素比例不匹配、retime/effects明确拒绝。

这是**best-effort软件服务/真实UI预览**，可能跳帧、晚帧并保持上一张图像；20ms新帧采纳
检查不是显示延迟上限。未测人耳/声卡DAC/物理AV同步/无缝resume/稳定帧率。普通Pause→Resume
现在从确认paused sample重建有新epoch的stream，等待新时钟，公开snapshot的未确认队列量，
不承诺物理队列精确取消或没有重复尾音。重绑/后台不自动恢复声音。

### 资源/兼容性与证据

* 每源≤2048帧，源≤2048²，RGBA最大128边；采用代理≤64MiB，同时单staging≤64MiB，
  像素LRU2MiB。不是全局进程/磁盘上限；崩溃orphan回收、持久CAS map/pins/历史闭包尚未完成。
* CFR/VFR/非零7秒原PTS各20点真实解码对照；VFR仅独立代理映射测试，不扩大编辑/导出profile。
* 实际 **179个Dart/Flutter测试（169 native +9 Chrome +1真实OS-keyring UI），0跳过**；
  另6个Python工具case、3个CTest各ON/OFF配置、真实60秒PCM→Dart AudioBus→AAC/mux资格。
  SIGKILL50次、AAC/无声各10次取消是内部实验，不额外冒充独立case。
* 实际Pulse服务monitor、SIGSTOP生产者饥饿、设备suspend、server stall、确认暂停/普通resume/
  重复resume/seek/rebind、FD与非本地服务拒绝回归通过；不等于物理设备或V004/P0资格。
* v4/v5/v6→v7实际SQLite迁移及旧runtime拒绝通过；原104 SHA256与87项原验收/依赖保持。
* Linux C++异常在真实Flutter宿主触发的abort已定位并隔离GNU runtime，C ABI只导出sm_*；
  真引擎加载时sync/async错误回归通过。仅Linux验证，不声称其他系统ABI或生产再分发资格。
* 当前6次clean/release构建启动复验记录以summary最终状态为准，不借用旧构建结果。
* 已知RTC受管网络策略阻塞保持；本批未无变化重跑正向资格、改策略、加中继或绕过限制。

细节：[ADR0012](../adr/0012-clock-driven-derived-video-preview.md)、
[三轮实际审查](REVIEW.md)、[实际汇总/源哈希/失败证据](evidence/timeline-proxy/summary.json)。

可复跑入口（先设置上文PATH/LD_LIBRARY_PATH/STUDIO_MEDIA_LIBRARY）：

```sh
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build /自己的native-build --report /自己的结果/native.json
python3 tools/acceptance/run_audio_qualification.py --native-library "$STUDIO_MEDIA_LIBRARY" --report /自己的结果/offline-60s.json
# 该脚本自行建私有null-sink；必须新bus，不能同已有服务竞争D-Bus名称。
dbus-run-session -- python3 tools/acceptance/audio_sink/pulse_smoke.py
cmake -S native/studio_media -B /自己的off-build -DSTUDIO_ENABLE_PULSE=OFF
cmake --build /自己的off-build && ctest --test-dir /自己的off-build --output-on-failure
dart run packages/studio_media/tool/pulse_off_proxy.dart /自己的off-build/libstudio_media.so /自己的合成输入.mp4
```

工具：Flutter3.50.1 / Dart3.14.0 / SQLite3.54.1 / FFmpeg7.1.5 / libpulse17 /
SWR5.3.100 / Clang19.1.7；诊断GDB16.3/strace来自官方Debian包，仅自有合成子进程。
不读取Mac/用户素材/现有keyring，不付费/部署/下载权重、不启用远端workflow、不合并main。
下一接续点：原I-002持久SchemaProxy/CAS资源与历史pins/ownership回收及rich Schema只读UI，
再做完整CPU/GPU effects/编码前patch/texture lease资格；现有preview临时格式不得静默写入Schema。
