# 可运行本地视频开发切片

**不是完整视频编辑器，也未完成全部87项。** 已有真实双 Flutter 宿主与共享 Dart/C++：
素材导入 → 单轨 split/trim/slip 等 → SQLite 事务 → 含原件工程 ZIP 保存 → 关闭重开 →
安全 fork 恢复 → FFmpeg 软件 H264/MP4 导出。原件/数据库不上传，无模型或付费 API。

视频范围仍为 CFR Rec709 limited 8bit、1×、相同偶数尺寸 ≤2048；持久音频/AAC与真实本地服务试听见increment1.7。
有音轨输入需明确 video-only 确认；未知色彩、VFR、旋转、alpha 等不伪装成可导出。
原104文档不变；当前全部87项逐项保留原验收：26 partial、48 planned、13 blocked（验证资源）。
**整任务完成数为0**；blocked 不等于实现完成，尚有大量可继续的纯 Dart 工作。

当前操作入口见文末 **increment1.21**；此前旧计数是各自冻结源码的历史切片，以task-status和最新summary为准。

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
* 当前最终源代码双Linux宿主各3次clean/release构建启动通过（共6次），另3次最小ABI探针通过；不是借用旧结果。
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


## increment1.9 — 持久代理 / PTS-map CAS与历史资源

原87仍0 complete /25 partial /49 planned /13 blocked；XD10仍单列0/8/1/1。
I-002/I-021获得下述可复跑实现，不代表全部原验收已闭合。原104和原验收/依赖不变。

Linux现有Build timeline video preview proxies按钮现在将已注册CFR/SDR RGBA128代理与
精确原PTS sidecar写入CAS，并以revision/writer CAS一次采用到原Schema的proxyRefs/blobs。
这是真正持久资源，不是临时路径或新根字段。首次成功增加revision；再次点击、归档/fork/
关闭重开可复用已验证资源，不新增revision。Play也可lazy-load持久proxy。Clear只清reader/
cache，不删除项目/历史持有的CAS资源。导出仍从原件按相同source-time graph编码，绝不截屏/
编码低清代理；原MP4/AAC保存恢复路径保留。

资源同时验source hash/原生源事实、pipeline/sourceVersion、原origin/timeBase、每帧有理时间/
长度/哈希、整blob/PTS-map与规范路径/role。自洽checksum不证明源像素：本机受信生成记录不
进入ZIP/peer；没有记录的外来派生首次接纳时实际native重算一次并比较完整结果，失败不创建
项目。其他CPU/平台严格字节重验未资格，不保证跨任意端即插即用；详见ADR，不称签名认证。

数据库保留所有历史revision的blob pins；实际undo后GC仍保护原件/旧代理/map。真实SIGKILL
持锁worker后，下一次显式build/reuse或Collect local garbage回收已知native/copy/map staging，
不跟随symlink、不递归、不删未知版本/其他文件。尚未实现启动UI自动扫描/历史裁剪/整个CAS
总配额。每个live root RGBA<=64MiB、单stage<=64MiB、map<=1MiB、像素LRU2MiB，不是总磁盘/RSS上限。

新增3个复杂native-backed测试实际涵盖：归档/fork/重开/原件导出、重复采用无revision漂移、
历史pins/损坏map/raw/缺引用/循环/路径/PTS/overflow、自洽假像素拒绝与独立namespace合法重验、
真实中途输出后的revision冲突、真实持锁SIGKILL及三个stage回收。内部断言不伪报独立case数。
第一轮全172-case回归实际有4个音频/AV/UI失败，已保留；不能将旧179通过或本轮3个新case通过
当成本轮全部回归成功。最终完整结果/工具版本/命令/失败以最新evidence汇总为准。

best-effort视频跳帧/保持旧图、非物理AV同步/非稳定帧率限制不变；原VFR独立seek测试保留，
不擅开持久VFR/任意pipeline。rich Schema只读UI、损坏代理显式丢弃重建UX、全资源类型及
P0/非Linux/物理跨设备验收仍未完成。已知RTC政策阻塞没有重试、放宽或中继绕过。

[ADR0013](../adr/0013-durable-preview-cas.md) · [证据](evidence/durable-proxy/summary.json)

新增复跑入口（沿用PATH/LD_LIBRARY_PATH=已批准SQLite3.54.1/STUDIO_MEDIA_LIBRARY）：
```sh
dart test packages/studio_sdk/test/durable_proxy_test.dart --reporter=expanded
python3 tools/acceptance/run_local_video.py --profile linux-dev --native-build /自己的native-build --report /自己的结果/durable.json
```

Final increment1.9 frozen-source evidence: **172 native +9 Chrome +1 actual OS-keyring UI =182 distinct Dart/Flutter tests,0 skips**; 6 Python tool cases,3 native CTest; six clean Linux release builds/first-frame starts (three per host) and three minimal ABI probes passed. Actual offline60s AAC/mux, private Pulse fault fixture, explicit Pulse-OFF refusal and v4/v5/v6→v7 migrations passed. Evidence: `evidence/durable-proxy/summary.json`. First full gate's four real audio/UI failures remain recorded; final pass does not prove intermittent underrun/load fixed, physical synchronization or P0 qualification.


## Increment1.9.1 — bounded readonly Schema inspection checkpoint

Native: enter an explicit local project JSON path → `Inspect project JSON (read-only)` →
`Inspect explicitly selected local JSON path`. Native/Web can instead paste JSON and
validate it. Every preserved root section is selectable, entries/JSON are paged,
exact id/hash lookup reports metadata paths. Opaque plugin data and locators are
text only: no resource is opened, plugin executed, network connection created or
active project replaced. Maximum inspection input1MiB; core Schema32MiB unchanged.

The original rich image/story/font/provenance fixture is actually inspected in a
Flutter widget; native file inspection preserves SQLite head/revision/undo across
reopen. Duplicate JSON, unsupported version, invalid FK, overlimit and dispose
while pending have real widget/Chrome tests. This is **not** rich-project editing,
SQLite import, archive repair, blob-byte/provenance or capability admission.

Small checkpoint only: **10 native UI +3 actual native durable-proxy regressions +3
Chrome =16 targeted executions,0 skips**, clean analyzer. Prior full182 and six
release-start results belong to frozen proxy commit e11ce9a; the full gate and
release builds were deliberately not rerun for this follow-on UI checkpoint.
Failures/corrections and hashes: `evidence/schema-inspector/summary.json`.
Original87 stays0 complete/25 partial/49 planned/13 blocked; XD10 stays0/8/1/1.


## Increment1.9.2 — explicit proxy-reference discard (small checkpoint)

Select an imported video/audio clip → check the explicit, revision-bound proxy
consent → `Detach selected asset preview references (no file deletion)`.
This removes only that asset's current proxy refs and now-unused derived Blob
metadata, versions affected references through the normal transaction and stops
preview. Originals, ALL CAS files and undo/history pins remain untouched. Shared
proxy hashes still referenced by another asset stay in the current root.
`Clear memory cache only` is separately labeled; build reports built/reused counts.

Missing-file recovery: detach → Build restores the missing registered proxy from
verified originals. For corrupt immutable CAS bytes, detach permits original-source
export and original-only archive/fork/reopen, but a later rebuild with the same hash
still FAILS CLOSED (`BLOB_HASH_MISMATCH`). No corrupt-file overwrite/quarantine is
claimed. Unsupported recipe metadata is STILL refused by existing admission;
this operation does not bypass it. No namespace quota/history pruning added.

Current frozen source:76 domain/store/native SDK +2 native Flutter UI =78 targeted
executions,0 skipped; analyzer clean. Evidence `evidence/proxy-discard/summary.json`.
This is NOT the182 full suite or release rerun; e11ce9a's182 and39202f41's16 retain
their own frozen-SHA scope. Intermittent audio stress failures remain unresolved.
All87/XD10 statuses unchanged,0 complete. Other platforms/physical devices untested.


## Increment1.9.3 — source-qualified, exclusively owned CAS repair

In a namespace bound at EMPTY creation to one database, select the clip → check
`Repair corrupt/missing selected preview CAS...` → `Repair selected preview CAS`.
Originals are really re-probed/hashed and native proxies regenerated; only the
exact expected registered hashes can publish. A SQLite writer/revision fence and
all-history role/project scan refuse originals, unknown ownership or another
project's pins. Valid CAS bytes are never overwritten. Project revision/hash,
undo/history and original bytes remain unchanged. A real process SIGKILL between
individual object renames is recoverable by the next explicit repair; prepared
and verified audit files stay local. The pair is NOT atomically published together.

Important: legacy nonempty/unbound namespaces and another database using the same
CAS refuse repair. No retrospective ownership assumption, silent Admission bypass,
recipe conversion or original repair. Existing discard/original-export paths stay
available. Audit cap256 and ownership/history scan cap10000 immutable objects are
fail-closed limits, not a namespace disk quota. No history retention/pruning or
automatic repair was added. See ADR0014 for trust/crash/legacy boundaries.

This source checkpoint: **63 store/SDK +3 real native UI =66 targeted executions,
0 skips**. Additional focused3 rerun is already included, not double-counted.
Actual SIGKILL, writer/revision/cancel fences, protected original-role fixture,
other-project pins, second-database usage, legacy and symlink refusals are tested.
Fenced-writer shutdown now closes resources without overwriting a new owner's
checkpoint; unrelated checkpoint failures still propagate. Evidence:
`evidence/proxy-repair/summary.json`; earlier failures are retained.

No full182/release/Chrome/physical-platform rerun; older frozen SHAs keep their
own coverage. Prior intermittent audio underruns remain unresolved. Original87
stays0/25/49/13 and XD10 stays0/8/1/1 (complete/partial/planned/blocked).


## Increment1.9.4 — namespace用量、写入预算与崩溃记账回收

Native App展开 **Namespace storage budget (keep all history)**：只读盘点 →
输入十进制字节上限（空白不限额）→ 显式勾选 → Apply。默认保留全部历史和原件，
不删除、不上传；旧/共享且无法证明单DB所有权的namespace拒绝改策略。

实际导入、map/CAS写入、native代理生成/安全修复与foreign来源资格都复用同一维护
OS锁预留空间；不足明确拒绝，不以删历史换空间。实际SIGKILL后只回收失效预留记账，
16KiB残留stage仍存在并计入盘点；失败/取消释放记账。排队源文件增长被拒绝，两个
并发6000字节写入在不足双份空间时恰好一个成功。策略随namespace重开/归档fork保留，
工程revision与原件不因配置改动。

**不是整盘quota**：仅CAS目录regular-file逻辑字节（含stage/未知文件/元数据），
不含DB/WAL、外部归档/导出/音频临时卷、分配块和volume可用空间。native保守预留
192MiB+每asset约1MiB，可因此拒绝小预算下的小代理；不是实际空间/RSS预测。
只新增固定preserveAll策略，**可配置历史pruning仍未实现**，无自动删历史功能。

本冻结源码：**66个store/SDK +4个native UI =70个定向测试，0跳过；analyzer与格式检查通过**。
新增3个SDK复合case和1个实际widget操作case，内部实验不重复计数。
证据/sourceHashes/复跑命令：[summary](evidence/namespace-budget/summary.json)、
[ADR0015](../adr/0015-namespace-cas-byte-budget.md)。全量182、release/CTest/Chrome、
完整迁移矩阵和音频压力未重跑，间歇underrun仍未解决。非Linux/物理多设备未验证。
原87仍0 complete/25 partial/49 planned/13 blocked；XD10仍0/8/1/1，原验收依赖不变。
下一接续：默认preserveAll的可配置历史保留/剪枝，需要显式dry-run和确认，保护所有
有效pins/角色/当前工程/其他工程/跨DB共享；先仅在隔离fixture验收，不能清理真实资料。


## Increment1.9.5 — 显式恢复点保留、命名pin与可审计index pruning

Native展开 **Recovery checkpoint retention**：可永久命名当前checkpoint（重名拒绝）→
选择保留最近1–10000个或空白preserveAll → 显式配置（不删除）→ Dry-run →
核对候选数量/前20个ID/hash → 单独勾选确认 → Apply。
“Read recent retention audit receipts”可看最近20份本工程持久回执。
所有删除实验仅在隔离临时fixtures执行，未清理任何真实工程。

**只剪除符合策略的checkpoint索引行，不剪除快照、undo/命令、revisions、blob pins或CAS文件，
不宣称释放磁盘空间。** 当前/最新恢复点、命名版本、所有保存操作、存在Harness会话的工程
均保守保护；其他工程/namespace不选中，旧/共享DB ownership不明拒绝操作。
默认preserveAll；预算不足、启动和后台从不自动触发剪枝。

review绑定revision/root/writer-fence/策略/pins/候选全集；确认时重新核验，事务中原子删除和
写入完整审计。SQL失败、最终权限丢失及真实SIGKILL均验证rollback；重开后新writer需重审。
SQLite增量至v8，旧1–7校验和与3.54.1严格runtime门禁不变。未重跑完整旧版本迁移矩阵。

年龄窗口/显式保存点轮换、备份策略及实体/资源历史压缩未实现；不以此代替原完整验收。
命名pin/策略/审计属于原workspace本机历史，不假称包含在固定R fork工程包中。
见[ADR0016](../adr/0016-explicit-checkpoint-index-retention.md)及
[evidence](evidence/checkpoint-retention/summary.json)。下一步回到I-002其他资源闭包，
避免继续无界扩建存储。原87/XD10计数不变，跨端/音频underrun限制仍保留。

本冻结源码实际73个store/SDK＋5个native UI＝**78个定向测试通过，0跳过**；
analyzer、10个修改Dart文件格式检查通过。新增6 store＋1 SDK＋1 UI case，内部SIGKILL等
实验不重复计数。旧182/70不是此SHA全量证据；完整迁移矩阵/release/Chrome/音频压力未重跑。


## Increment1.10 — 非代理资源只读保全实际文件路径

Native App展开 **Preserve project resources (READ-ONLY, no render)**：
显式选择Project JSON → 查看缺失字节/角色/未知闭包诊断 → 逐个显式选择声明资源文件
（实际SHA256匹配，不按文件名猜测）→ 确认本机收集 → 新路径保存JSON或资源ZIP →
重新打开ZIP → 注册的媒体/图层/字体子集fork → 再显式保存。

这是**独立只读文件视图，不是可写工程导入，不切换当前工程，也不写SQLite/CAS**。
原件、历史/命名pins、namespace ownership/预算和会话fence保持不变。
JSON1MiB、单资源64MiB、收集总量128MiB；归档沿用既有容器/路径/hash校验。
输出使用Linux同目录no-clobber原子发布，现有文件绝不覆盖；空间unknown/ENOSPC
和跨平台未验证。实际两进程同时准备并发布同一新目标仅一个成功。

目前可枚举/诊断并保全字体、效果/图层mask、imageDocument源与声明Blob；
**字节hash/size一致不等于格式/字体可用、许可证真实或render可执行**，报告始终明确
格式未验证和执行不支持，不把ZIP写完称selfContained。
未知LUT/library/plugin扩展保留opaque，阻止假完整归档/猜测ID重映射；可保存元数据JSON。
模型只保留引用不下载。字体embedAllowed/licenseRef事实显示为风险，不伪造授权。

只读fork已按注册字段重映射媒体/stream/sequence/track/clip/rights/font/layer/effect引用；
未知扩展、历史定义、story等不支持的fork profile拒绝。完整ImportMap/SQLite采纳、
字体/图像/LUT格式资格及渲染、library walkers仍未完成，原整任务不因此标complete。
详见[ADR0017](../adr/0017-readonly-resource-preservation.md)和
[evidence](evidence/resource-preservation/summary.json)。Web仅验证纯图闭包/只读Inspector，
不是Web文件保全功能，更不是跨物理设备资格；RTC网络阻塞未重测或绕过。

Freeze evidence: **152 selected cases passed** (142 native SDK/store/domain +6
actual native widgets +4 actual offline Chrome graph/inspector),0 failed/skipped,
plus clean analyzer. Seven are new cases, not152 new features. Exact commands,
source SHA256, versions and retained failure logs: [resource evidence](evidence/resource-preservation/summary.json).
Not a whole-repository/full182 rerun; release/native ABI/full migration/audio
stress/non-Linux/physical-device checks were not rerun. Intermittent service
AudioSink underrun remains unresolved. Original87:0 complete/25 partial/49
planned/13 blocked; XD10:0 complete/8 partial/1 planned/1 blocked.

## increment1.11 — resource-aware writable fork and actual retained definition closure

Native resource panel: load source JSON/archive, explicitly collect declared files,
review report and select collection consent, then **Qualify and open NEW writable
fork (supported renderer only)**. This does not replace the old project. Only the
existing implemented timeline profile passes, after actual source metadata/first-
video-frame or1024-sample PCM qualification and final revision/writer fence. A
successful fork is normally editable/saveable/reopenable/exportable and its local
ImportMap is durable. Unsupported font/mask/image/LUT/library/retained rendering
remains explicitly read-only; no opaque record is removed to pass this gate.

Retained definitions now accept only actual <=1MiB full Project2 snapshots matching
origin and exact kind/id/version, explicit dependency pins and bounded nested
reference closure. Actual JSON/resource archive/reopen is supported, NOT retained
execution or full render-definition equivalence qualification. Missing/hash/pin/
role/origin/opaque errors remain distinct from format/business capability.

SQLite additive v9 contains only the required ImportMap provenance. No budget,
retention/GC or external protocol redesign. History/originals/shared objects remain
protected; failed imports may leave valid counted unadopted CAS objects for existing
conservative recovery/GC, never automatic deletion. See [ADR0018](../adr/0018-resource-aware-writable-fork.md).

Final frozen source: **167 selected tests passed** =155 native SDK/store/domain
(including actual AAC/export) +1 separately isolated real Pulse SDK +7 native
widgets +4 actual offline Chrome;0 failed/skipped in this final selection, clean
analyzer. Twelve cases are new. Five actual historical v4-v8 -> v9 experiments
plus old-runtime refusal are separate, not inflated test counts. Exact sources,
commands and retained initial fixture/Pulse failures: [evidence](evidence/resource-admission/summary.json).
No full-repository/60s/CTest/ABI/release/nonLinux/physical-device claim; historical
intermittent underrun unresolved. Original87 remains0 complete/25 partial/49
planned/13 blocked; XD10 remains0 complete/8 partial/1 planned/1 blocked.

Reproduce the actual v8 fixture migration (other original baseline commits/versions
are listed in the evidence; v4 uses the isolated old system library):
```sh
python3 tools/acceptance/verify_sqlite_upgrade.py --baseline-commit fceda897 --baseline-schema 8 --baseline-library-dir /workspace/toolchains/sqlite-3.54.1 --library-dir /workspace/toolchains/sqlite-3.54.1 --report artifacts/local-video/recheck-v8-v9.json
```

## increment1.12 — resolved frozen definition identity and live version guard

Existing native resource report now shows a core root definition identity (or an
explicit unqualified error). It resolves pinned frozen definitions and actual
known dependency data, rather than hashing only the literal Sequence object.
Same-version frozen definitions with changed resolved dependencies refuse resource
qualification/packaging. Inspection remains opaque/read-only when semantics are
unknown. Digest equality is NOT render-equivalence or execution qualification.

Normal writable timeline gain/pan/edit/save paths continue using the existing
renderer; an in-transaction current-head guard rejects unchanged sequence versions
when their rendering dependencies change. No new effects/font/mask/image/library/
LUT/retained execution admission. Legacy persisted hash rows/history are not
silently migrated to this new profile. See [ADR0019](../adr/0019-resolved-definition-identity.md).

This regression also corrected a real audio-edit version propagation bug: changing
master gain/pan/mute/solo now advances the owning sequence version; an identical
operation is still a no-op. Track/sequence-owned effect ordering and transitions
are explicitly unqualified rather than omitted from the identity. Physical sound/
sync and the existing intermittent service resume-underrun are NOT qualified.

Frozen increment1.12: analyzer/format clean; **178 selected cases** passed on the
final exact Dart source (165 native/domain/SQL/SDK +1 isolated actual Pulse service
+7 Flutter widget flows with native FFI +5 actual Chrome). New cases:10 domain and
1 Chrome. See [exact source/commands/results](evidence/definition-identity/summary.json).
An intermediate service run reproduced the existing resume underrun; its full
failure remains retained. Final isolated success does not mean it is fixed. This
is not a full-repo/release/physical platform or 60s stress requalification. Existing
historical migration/fault unit paths reran; the previous five separate old-binary
v4-v8 experiments did not. No fresh native/window build or native code change.

## increment1.13 — existing project history remains usable and immutable

The current Linux/runtime edit path now checks exact resolved versions against
real anchored historical snapshots, including noncurrent versions. Legacy raw
hash rows and original bytes are not rewritten. Actual old bus edits that reused
sequence version0 remain readable; validated undoLatest can restore their exact
old state, then normal edits allocate new versions. Arbitrary new reuse of that
ambiguous version still refuses. Existing archives/forks/save/reopen stay isolated.

No schema migration/new tables or renderer expansion. The rebuildable proof cache
is bounded; zero cache performs the same checks by streaming, not by bypass.
Unsupported resources remain preserved read-only/refused for execution. See
[ADR0020](../adr/0020-legacy-definition-history-compatibility.md). Current schema9
does not prevent old executable co-writers; all writers must use the guarded
runtime. This is not full historical-story/session migration or all-I-002 closure.

Frozen increment1.13: **187 selected passes** (174 native/domain/SQL/SDK +1 real
isolated Pulse service +7 Flutter widget/native FFI flows +5 actual Chrome),
including9 new store cases; analyzer/format clean. Separate actual old-library and
instrumented-temp SIGKILL/reopen experiment is not counted as Dart/App tests.
[Exact source, commands and failures](evidence/definition-history/summary.json).
The existing intermittent resume underrun is not fixed by this isolated pass.
Full repository/release/platform/60s and new RenderGraph consumers not qualified.


## increment1.14 — 可操作的静态透明度效果

Linux Native 编辑器：导入本机 SDR/CFR 视频→点选 VIDEO clip→`Selected VIDEO opacity [0,1]` 输入0.5→`Apply persisted clip opacity`→`Preview selected timeline clip effect`。同一节点接入 AudioSink 服务确认 sample 时钟选择的 timeline 预览和原件 MP4 导出；不是 proxy 乘像素、不是截图导出。支持版本、undo、保存、关闭重开、归档 fork 和经真实 native 资格验证的资源采纳。0是黑色、1保持原图；黑色项目背景、静态单节点，其余不可执行资源继续只读保全/拒绝。

真实像素证据：原件全尺寸共享 C++ linear-light BT709 opacity，编码提交前捕获实际 YUV420 取样（最多4帧）。128×72独立灰块数学参考容差≤2/255；320×180彩色视频比较128×72显示样本，不能泛称全分辨率/GPU/全片等价。FP32 transfer + RGB8 staging 不是原 FP16 GPU 合成资格，详见 [ADR0021](../adr/0021-static-linear-opacity-consumer.md)。

[冻结源代码/真实命令/结果/早期失败](evidence/static-opacity/summary.json)。I-008由 planned 改 partial，I-022/V-003仍 partial；原87为0 complete /26 partial /48 planned /13 blocked；XD10仍0/8/1/1。原104与原任务验收未改。新媒体消费者需要重新构建本机 native library（原 CMake 构建目录及批准 FFmpeg/Pulse 工具链），SQLite严格使用3.54.1；示例运行环境沿用此前说明，不把系统 DEV SQLite 当合格。

限制：完整 registry、变换/关键帧/转场/GPU/100次取消 frame-leak 资格未完成；非Linux、物理多设备、物理声画同步没有新验证。已有 resume underrun 未解，不因本次隔离测试通过消除；RTC 策略阻塞不重复尝试或绕过。下一接续是原 I-008/I-022 有用变换/关键帧或同一消费者的逐项像素/生命周期验收，而非继续扩存储。

本冻结代码实际通过 **200项所选 Dart/Flutter/Chrome 测试**（183领域/SQLite/原生SDK，9真实native UI，5 Chrome保全/检查器，3真实私有Pulse服务）及 **3项CTest**，analyzer无问题；另跑真实旧库/SQL-barrier SIGKILL恢复实验，不计入200。不是全仓库/全部87验收全过，也未重跑早期60秒资格矩阵。完整日志、精确源码及native library哈希见同目录证据。


## increment1.15 — clip-local透明度关键帧与取消修复

Native编辑器导入→点选video→在opacity value和`Clip-local project frame`填值→选择Hold或Linear→`Set / replace opacity keyframe`。例如本地frame0/value0、frame60/value1构成两秒线性淡入。frame30预览会消费真实原件/相同native节点；可Remove显式点、一次Undo恢复、保存/重开/归档fork/MP4导出。静态Apply不会悄悄清空曲线；duration endpoint仅是控制点，不能预览成下一clip。

曲线依clip-local project time，不随slip移动；split/trim边界插值/右侧重基准，move不改局部点、延伸hold裁切后边值。详细坐标、半开边界和CPU/资源限制见 [ADR0022](../adr/0022-clip-local-opacity-keyframes-and-cancel-ownership.md)。完整多级undo/redo栈、gesture coalescing、其他effect/keyframe参数/转场/GPU仍未完成。

新的100轮active取消测试发现并修复了decode取消抛异常时current/next指针别名导致的double-free；自有AVFrame与FD回到baseline，另跑ASan/UBSan（leak检测开启）。本冻结源码定向209个Dart/Flutter测试（190 native/domain/store、10 UI、5 Chrome资源/Inspector、4真实私有Pulse）全部通过，另CTest3项、实际legacy/SQL barrier/SIGKILL重开实验、普通与ASan/UBSan各100轮scheduled-opacity取消均exit0；analyzer无问题。非全仓全测。具体通过/失败数和精确冻结源代码证据见 [本批summary](evidence/opacity-keyframes/summary.json)，不是旧200套复用；GPU/第三方内部未instrument资源不能假称全资格。原87仍0 complete /26 partial /48 planned /13 blocked，XD10仍0/8/1/1，原104/验收/依赖不改。


## increment1.16 — 静态2D变换，共用真实预览/编码像素

Native UI导入→选VIDEO→填写Transform X/Y（画布像素）、uniform scale、clockwise degrees→`Apply persisted transform`→沿原本地frame预览按钮预览→Undo/保存归档/fork/重开/导出MP4。UI按钮显式使用source-center anchor；同一SDK setClipTransform支持完整独立scaleX/Y与anchorX/Y。transform可与上一批clip-local hold/linear opacity曲线组合，原split/trim/slip语义保持。

真正执行M逆矩阵、像素中心、linear-light双线性与透明越界coverage，先transform后opacity，原件全尺寸同一native节点同时供预览与encoder-input，不拿RGBA128代理冒充源或UI截图导出。identity真bypass。CPU、同尺寸opaque SDR/Rec709 limited YUV420/黑背景，FP32 transfer与RGB8 staging，不冒称GPU/FP16/alpha源、多轨或全平台。超出本CPU有界坐标/scale profile明确拒绝，未知/动画transform等继续保全只读、不清空降级。

本冻结源码216项定向Dart/Flutter测试通过（195 native/domain/store、11实际FFI UI、5 Chrome资源/Inspector、5真实私有Pulse），另CTest3项、真实旧库/SQL barrier/SIGKILL重开通过。opacity及transform+opacity两种活动取消各普通/ASan100次，共400轮；每轮自有AVFrame回baseline、各运行FD delta0，非GPU/第三方内部全资格。analyzer无问题，不是全仓全测或旧209重用。本批精确冻结测试/真实取消/失败证据见[evidence/static-transform/summary.json](evidence/static-transform/summary.json)，参数/色彩/alpha/采样限制见[ADR0023](../adr/0023-static-transform2d-cpu-reference.md)。原87仍0 complete/26 partial/48 planned/13 blocked；XD10仍0/8/1/1。原104/原验收/硬依赖未改，多级undo、真实resume underrun、旧writer共写、GPU/物理/其他平台与RTC限制保留。


## increment1.17 — 有真实源handles的VIDEO叠化，双源共用预览/编码

Native编辑器可实际操作：导入≥3秒的SDR/CFR素材→选VIDEO、`Positive frames`填30后Split（以30fps为例）→给右clip设置不同transform/opacity→选左clip、`VIDEO dissolve before/after cut`各填6→`Dissolve selected LEFT → next`。选右clip本地frame0点击timeline-effect预览即可看cut的混合帧；可一次Undo、移除转场、保存、归档fork/关闭重开和导出MP4。没有足够A尾/B头handles明确拒绝，不自动冻结。两个不同原件也适用同尺寸/色彩等已实现profile，不只同一素材切开。修改split/trim/move/roll/slide需先显式移除转场，slip必须重新通过handles校验。

时间窗严格[b-p,b+q)，每腿先独立transform/clip-local opacity，再linear-light叠化；共享Dart精确source-time/Q16混合schedule及C++全源像素节点供still、服务确认sample时钟预览和真正encoder-input。不拿代理缩图或UI截图导出。VIDEO-only，不自动给AudioBus添加等功率fade；如需试听沿既有持久AudioClip/AudioSink路径，真实服务underrun仍未解。当前1x/linear/reject、同尺寸709 limited YUV420、黑底CPU FP32/RGB8，非GPU/FP16/全alpha/全registry/任意平台。详见[ADR0024](../adr/0024-video-dissolve-handles-cpu-consumer.md)。

最新冻结源码所选**225项：224通过、1失败、0跳过**（202领域/SQLite/native SDK全过，12实际FFI UI全过，5实际Chrome资源/Inspector全过；6私有真实Pulse服务中5过1失败）。失败是既有`opacity_clock_test`服务timeout/underrun，同一症状首轮冻结也复现；保留非零资格，不重试刷绿。新增双源dissolve-clock实际通过，不表示旧underrun已修好。另CTest3项、真实旧库/SQL barrier/SIGKILL重开通过；原opacity、transform+curve、新双源dissolve+transform/curve三种活动取消各普通/ASan100轮，共**600轮**，自有AVFrame回baseline、每运行FD delta0。不是GPU/第三方内部全生命周期资格或全仓全测。

[精确源码/二进制hash、命令、逐case结果、非零失败和前一冻结](evidence/dissolve/summary.json)。前一冻结224项与最新225项分开，旧216/209不混算。显式ResourcePreservation采纳先真实执行已启用transform和joint窗口样本，再原子发布fork；不只是capability flag。实际SQL后段abort/stale revision/双leg不可变闭包、typed effect/transition ImportMap、归档fork/reopen、坏尺寸门禁均有证据；原件/pins/历史/旧hash不重写，无真实资料清理。

原87保持**0 complete/26 partial/48 planned/13 blocked**；XD10保持**0/8/1/1**。I-008/I-022仍缺registered luma/全registry、I-005多级undo和完整V-003/GPU硬门禁，不以本子集改写原验收。原104不改；旧writer共写、单级inverse、非Linux/物理多端/物理声画同步与RTC既有策略阻塞仍保留。后续回原I-008/I-022有用的registered crop/colorBasic消费者及原I-005/I-023缺口，不扩存储指纹旁支。


## increment1.18 — 可持久的 Crop / ColorBasic，真实原件像素链

Native编辑器导入受支持SDR/CFR视频→点选VIDEO→填写 `crop-left/top/right/bottom`（源归一化，默认0/0/1/1）→`Apply persisted crop (static CPU)`。例如left=.25裁掉源左四分之一但不改变画布尺寸；填写 `color-exposureStops`、`color-contrast`、`color-saturation`→`Apply persisted colorBasic (static CPU)`。随后沿原timeline-effect预览、单次Undo、保存、关闭重开、归档fork和MP4导出。可与已有静态transform、clip-local opacity曲线及带真实handles的VIDEO dissolve组合；两个leg有各自参数。UI真实点击测试覆盖crop/color+dissolve路径，非identity transform/opacity组合的像素/归档/导出由实际SDK测试另验，不用测试名称代替操作证据。

共享原件全尺寸C++节点次序 **crop→transform→colorBasic→opacity→dissolve**；源像素边界half-open面积coverage、premultiplied线性采样、线性709曝光→.18对比→加权亮度饱和度，只在最终SDR输出clamp。preview和真实encoder-input同图；identity保持旧bypass，不滤RGBA128代理。原数学范围/顺序/边界及未指定亚像素coverage的明确CPU选择见[ADR0025](../adr/0025-static-crop-colorbasic-cpu-consumers.md)。crop/color动画、逆序/未知/资源型未实现节点仍只读保全、拒绝执行，不剥离语义。需重编译现有native库；旧库没有staticRasterV1会明确拒绝，不假装支持。

本冻结生产/测试源码实际所选**233项：232通过、1失败、0跳过**：208领域/SQLite/nativeSDK、13实际FFI UI、5实际Chrome资源/Inspector全过；7真实私有Pulse服务中6过1失败。失败为新增 `raster_clock_test` 在首次play等待>4800服务确认samples时underrun（presented2877、submitted5168、ring8192/8192、maxWorkerLoopGap2425us），尚未到该测试的renderTimelineFromAudioClock/暂停seek像素断言；**不能称本冻结新增clock端到端通过**。其早期单独定向通过另存，不借用；原00c2e5d的224过1 opacity_clock失败也保留。本轮opacity_clock虽过，不是修复，未改队列/timeout/断言、未重试刷绿。

另CTest3项、真实旧库/SQL barrier/SIGKILL重开成功；opacity、transform+curve、dissolve+transform/curve、新独立双腿crop/color四种active取消各普通/ASan100轮，共**800轮**，每轮自有AVFrame回baseline、各运行FD delta0，ASan/UBSan leak检测开启，无suppression。不表示codec/GPU内部全生命周期资格。真实12个主/副腿恶意recipe在创建输出前拒绝，SQL后段abort/stale revision、独立半像素/颜色参考≤2/255、四个实际编码前样本、归档fork/重开/资源采纳等通过；三轮实审和早期风格失败保留。[精确冻结hash/命令/所有结果与限制](evidence/raster-effects/summary.json)。非全仓/全87验收，非旧225/216/209混算。

原87仍**0 complete/26 partial/48 planned/13 blocked**，XD10仍**0/8/1/1**。原104、验收和硬依赖未改。I-008仍缺注册luma/完整registry及I-005硬前置；I-022/V-003仍缺全GPU/FP16/纹理lease与完整profile。黑底opaque SDR CPU/FP32+RGB8、同尺寸单轨1x限制继续；物理同步/稳定帧率/其他平台/物理跨设备未验，RTC策略不重试绕过，Schema9旧writer共写与单级inverse限制保留。下一批回原I-005多级undo/redo与有界原子提案逆操作，或I-023已保留的startup/resume服务故障，不继续扩存储指纹旁支。


## increment1.19 — Pulse readiness调度与真实不足诊断（仅本地，未发布）

保留e23a559的crop/color真实可操作路径；这批只改Linux Pulse worker调度与诊断，不改AudioBus/精确source时间或预览编码像素。原nonblocking iterate后无条件sleep2ms会延迟已经ready的工作，现用官方 `prepare(2000us)→poll→dispatch`：有事件立即处理、无事件最多请求等2ms，**不是呈现时钟/物理延迟承诺**。新增协商minreq、实际underflow字节位置/当时可写量、dispatch计数，便于下次故障定位。ring8192帧、server32768字节上限、target/prebuf/minreq、写batch/500ms stale及真实underrun中断冻结策略不变，不改prebuf0、不扩队列、不放宽断言。

一次仅加诊断而未改调度的两case和旧真实probe也通过，因此本批不能证明原间歇startup/resume不足的唯一根因。**旧00c opacity失败及e23a raster首次play presented2877失败仍未解**，不能以随后通过称修好。[ADR0026](../adr/0026-pulse-event-pump-and-underrun-diagnostics.md)记录明确修正与因果边界；[本冻结证据](evidence/audio-event-pump/summary.json)单列当前测试、真实monitor/SIGSTOP饥饿/设备丢失/服务stale/恢复/EOF及未跑范围，不混算旧通过数。

发布边界：本轮只读查询的适用branch rules=[]、repo rulesets=[]、branch protected=false且仍00c2e5d；公开Git Operations显示operational，但不足以解释 `fatal error in commit_refs_rules`。**原因未知，未证实任何用户必须修改规则/授权/身份的动作**。保留原push错误，无push重试、无绕过或扩权；e23a559及本批普通本地commit均未发布。原104/87验收依赖、SQLite3.54.1严格门禁、87与XD10独立状态保持。旧writer共写/单次inverse、Linux CPU/GPU/物理/其他平台/RTC限制不变。

本冻结实际**233项所选全部通过、0失败/0跳过**（208领域/SQLite/nativeSDK、13真实FFI UI、5Chrome资源/Inspector、7真实私有Pulse服务）；新增raster_clock与旧opacity_clock本次均通过，但不是间歇问题已修复。另真实monitor/fault完整probe、CTest3项、旧库/SQL-barrier/SIGKILL恢复成功；四种活动视频取消普通/ASan各100，共800轮，自有AVFrame/FD回基线。Pulse真实worker未跑ASan/TSan，不将视频ASan说成音频内存资格。不是全仓/全87/长时间负载/物理同步或其他平台验收。原87保持0 complete/26 partial/48 planned/13 blocked；XD10保持0/8/1/1。


## increment1.20 — 可持久多级Undo / Redo（仅本地）

Native编辑器可连续编辑crop/color/标题等→多次`Undo`→多次`Redo`；按钮按真实持久journal可用性禁用。关闭重开后仍可继续Redo；Undo后新编辑清可用Redo路径但不删除历史/事件/原件。SDK的undo/redo仍先停止播放/失效旧帧，事务内比revision/writer-fence和完整内容，只接受目标command ID，不接收任意快照JSON、不重跑模型/转码。普通保存不清栈，归档导入fork按原规格从revision0空本地栈开始；源工程栈留在原SQLite。

不是内存stack：复用现有commands/revisions/snapshots/receipts/pins，无新表或迁移，cursor由单一SQLite读取快照重建，失败不会先pop。旧undoLatest/API/raw hash保持，旧恢复动作作为实际历史步骤可遍历；新SDK连续Undo不再来回撤销上一次inverse。原始entity版本精确恢复，后续新写仍用历史max+1。**仅tip/full-content保守逆操作**，不自动字段级协作rebase、无gesture coalescing；当前O(n) journal折叠，不宣称巨量历史实时性能。完整Gap/多选/吸附/复制粘贴/编组等原I-005未完成，不能据新栈标整项complete。详见[ADR0027](../adr/0027-persistent-command-journal-undo-redo.md)。

真实路径覆盖UI多步撤销重做/保存/归档fork/预览MP4；SDK实际A/V+AudioClip/link、crop/color、caption及proxy逐态contentHash恢复/重开，显式Undo字幕后预览/编码前像素/MP4（不能偷偷丢字幕），再Redo保留字幕/代理。另1000个seeded标题历史逐态undo/redo，两独立连接同时Undo、late SQL回滚/幂等、原实际旧库歧义版本四undo四redo/re-edit、三次COMMIT前后SIGKILL。**准确冻结结果与未跑项以[本批证据](evidence/command-history/summary.json)为准**，不借旧233，不把1000标题历史说成全部NLE随机操作验收。

原104/87验收依赖、SQLite3.54.1严格门禁、87与XD10分列保持。startup/resume underrun仍未证解；旧writer共写、Linux CPU/GPU/物理同步/其他平台及RTC限制不变。本批不push、不换分支/身份/协议、不重新无证据诊断远端；e23a559、c8c12d8和本批均只在云端checkout本地普通提交中保存。

本冻结20份生产/测试源码实际所选**239项全过，0失败/0跳过**：214领域/SQLite/nativeSDK、13真实FFI UI、5 Chrome资源/Inspector、7私有Pulse。另CTest3项、真实旧库/SQL-barrier/SIGKILL及新增Undo/Redo三次SIGKILL、真实音频monitor/故障probe全过；四种active视频取消普通/ASan各100共800轮，自有AVFrame/FD回基线。是本批重新运行，不借旧233/182；早期风格检查与辅助脚本编辑失败单列保留。当前7项Pulse通过**不证明旧startup/resume underrun已修复**。本批没跑全仓、全87验收、fresh release窗口构建、物理/其他平台或大型历史性能；完整未跑清单见证据。原87仍0 complete/26 partial/48 planned/13 blocked，XD10仍0/8/1/1。


## increment1.21 — 连续手势只产生一次Undo（仅本地）

选视频片段→拖动新的static-opacity slider：按下固定project/revision/目标，移动显示未提交ghost及真实共享native静帧，松手才一条持久Command。一次Undo回到拖前，Redo还原拖后；保存重开继续历史，归档fork依原规格空本地undo栈。无变化tap/回到起点、Escape、pointer CANCEL、竖向滚动夺走gesture、切目标/关闭等不写gesture；SQL失败就在控件旁明确显示并保留候选，用户可取消，冲突不自动覆盖。旧数值Apply仍是离散替代；不把不同对象或不同手势偷偷合并。

SDK另对move/trim/slip、opacity固定时间关键帧值、transform/crop/color提供同base绝对更新/一次提交，验证边界和实际共享预览。**不是这些全部已有timeline拖动UI**，不是全I-005：多选/吸附/剪贴板/编组/插入覆盖完整矩阵、时间坐标关键帧拖动、字段级协作逆操作和巨量历史性能仍缺。仅现有黑底SDR CPU子集；ghost不保存、不导出，release后才走原版本/事务/pins/receipt，未加新存储或指纹体系。详情见[ADR0028](../adr/0028-gesture-ghost-single-command.md)及[本冻结证据](evidence/gesture-edit/summary.json)。原underrun间歇失败和旧writer共写限制不因本批通过而闭合。原104/87依赖保护，原87与XD10独立状态；不push、不再诊断远端，不改分支/身份/协议或规则。


本批最后26份源码/测试/package冻结后的**248项：248通过、0失败/0跳过**，分别222领域/SQLite/nativeSDK、14真实FFI widget UI、5 Chrome资源/Inspector、7真实私有Pulse；不是首次247的混算。另CTest3、真实monitor/故障probe、真实旧库与SQL/Undo三次SIGKILL、SDK独立child staged100次更新后的SIGKILL，以及四种视频active取消普通/ASan各100共800轮通过。原underrun两次历史失败仍未证解。前期shader/cwd/SQL错误可见性/格式/公共preview回归的真实失败均保留，最后修正后才重新冻结运行。未跑fresh release窗口构建、全仓/全87/全I-005、非Linux/物理设备/GPU及巨量历史资格。原87仍0 complete/26 partial/48 planned/13 blocked；XD10仍0/8/1/1。本地保留全部未发布祖先，不push、不重试远端诊断。


## Increment1.22 — 原I-005同轨多选/音画链接整组原子移动（本地未发布）

在原生工具App导入视频、拆分并提取链接音频后，可勾选多个视频/音频Clip，
使用共享正数Frame count输入框，点击`Preview selection +/- frame count`查看
**未提交**的真实native候选图与完整链接闭包，再选择一次Commit或Cancel。
未勾选的链接音频会显式列入闭包，不拆链接/不独立舍入，不静默跳过锁定成员。
空选集/重复ID/缺失ID/Gap或字幕选项/锁轨或起点字段锁/负起点/碰撞/音频非整sample
全部原子拒绝；转场只能同时移动两端，cut平移，source handles不变且重新校验。
候选失效时不会显示前一个有效ghost，不能提交旧值；Escape/取消/生命周期不写历史。
同一请求选集顺序不影响手势，但切换请求对象不能静默归并。原有tip/full-root
多级undo/redo、保存重开及归档fork语义不变。fork后旧选集不会默默裁剪：需显式清空。

该切片**仅同原轨/reject/includeLinks=true**。没有新插入/覆盖/跨轨/吸附/剪贴板/
编组/Alt临时脱链/任意指针拖拽/field-aware协作逆操作。绝对字幕仍保留原时刻；
clipLocal/source字幕锚定不支持编辑、字幕像素执行不支持时仍明确拒绝，绝不吞掉。
clip-local效果/关键帧、音频automation、素材/代理/链接offset均保全。精确音频尾点
落在视频帧间时，必要视频尾Gap向上取整项目帧以保留时长，不制造非法半帧Gap。

```sh
# 环境须使用前述已批准SQLite3.54.1和真实native库/合成视频fixture；不安装/下载模型。
dart test packages/studio_document/test/multi_move_test.dart packages/studio_sdk/test/multi_move_test.dart --concurrency=1 --reporter=json
(cd packages/studio_editor_ui && flutter test test/multi_move_ui_test.dart --reporter=json)
# 原I-005入口已按目录收集新domain/SDK/UI用例；下命令是更大的资格入口，不等于本批已运行。
python3 tools/acceptance/run_task.py I-005 --profile linux-dev --report artifacts/i005-full.json
```

详见ADR0029和`evidence/multi-move/summary.json`的冻结源码、当批真实测试与失败。
本批不修改存储Schema/原104规格/原87验收，不将100次同类移动等同全NLE1000随机矩阵。
原O(n)历史与区间索引性能、startup/resume underrun、schema9不能阻止旧writer共写、
Linux CPU/SDR子集非GPU/全平台/物理声画同步等限制仍在。WebRTC网络策略不变且未重试。
按要求仅普通本地提交，既有4个未发布祖先保全；本批不push/不重诊断远端拒绝。


## Increment1.23 — 原I-005精确吸附接入多选移动（本地未发布）

原生App多选视频/音频Clip后展开`Exact viewport snapping · 8 logical px`：
设置逻辑像素/秒、Viewport起始帧、指针x和编辑播放头帧，点击
`Preview exact snapped selection`。读出最近目标/类型/ID、原始与吸附后及最终Q位移、
距离与量化残差、参与轨，标尺显示候选，真实native候选图复用共享预览节点；
确认一次Commit，或Escape/Cancel无工程编辑。沿用持久undo/redo、保存重开、归档fork
和AAC MP4。缩放200px/s、origin15帧、pointer92px、playhead30帧的真实UI例子中，
原始0.96s以8逻辑像素吸附1s，完整4成员音画链接组一起移动。

最近优先，再播放头/切点/marker/ID；候选排除整个移动链接闭包。先吸附再帧量化，
音频独立移动使用48k sample格；混合时钟不独立舍入，不整sample整组拒绝。量化后
残差非零会明示。失败不选择另一个目标绕碰撞/锁/handles；非法数字和旧plan不能提交
之前有效ghost。marker仅通用纯计算排序有测试，现有marker工程仍保全只读/拒绝编辑，
不宣称marker业务支持。编辑播放头不是AudioSink已呈现时钟；标尺double仅用于绘制。
数值viewport预览/按钮确认不是完整pointer拖拽交互；没有新存储或注册协议。

```sh
dart test packages/studio_document/test/timeline_snap_test.dart packages/studio_sdk/test/snap_move_test.dart --concurrency=1 --reporter=json
(cd packages/studio_editor_ui && flutter test test/snap_move_ui_test.dart --reporter=json)
```

使用前述批准SQLite3.54.1/FFmpeg/native库与合成fixture环境；完整原任务入口仍按目录
发现这些用例，本批只运行summary列出的冻结选测，不等于完整I-005/87项验收。
新增真实AAC文件PCM检查仅确认移动后0–0.8s静音和1.1–1.2s存在音频，不声称AAC切点
sample-exact或DAC/物理延迟。原underrun仍未证解，既有失败保留；不重试受限RTC。
详见ADR0030、REVIEW和evidence/snap-move/summary.json。本批不push、不重诊断远端。

## Increment1.24 — real pointer timeline, atomic release

In the native workbench, click/Shift-click clips (or use existing selection), then drag horizontally on the visible clip tracks. The ruler, zoom slider and horizontal scroll correspond to actual measured logical coordinates. Snap line/feedback and latest native ghost follow the same linked atomic move planner. Only final physical release after latest native-frame validation writes one history command; Escape, scroll/focus/track exit, invalid candidates and zero change do not write. Undo/redo, archive fork and MP4 export remain actual existing paths. Numeric snap controls are no longer the only move interaction. See ADR0031 and evidence/pointer-drag for exact tests, retained early failures and qualifications.

The pointer-selected29/30s displacement exposed and fixed exact MP4 edit-list AAC duration truncation; sample counts and preencoder pixels are checked without weakening verification. This is NOT an AudioSink underrun fix. Same-track native CPU SDR subset only; no marker editor, mobile long-press/pinch, full operation matrix/GPU/physical-device qualification. Original87/XD10 acceptance/status remain separate and unchanged in completion count. Ordinary local commit only; six unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.25 — internal clipboard, cut/paste and selection groups

Workbench Copy/Cut/Paste/Group/Ungroup operate on the current selection plus its complete link and selection-group closure. The clipboard is internal and session-scoped, not the OS clipboard; it is cleared when the open project changes. Copy does not write the document. Cut and paste are one persistent command each (lift leaves legal gaps and keeps assets/blobs; paste rebuilds IDs, keeps source time, effect curves, proxy refs and audio offsets, same project / same-kind tracks / reject collisions only). Grouping is selection-only and is not an AV link. Locks, collisions, incomplete transition handles and unsupported marker/caption items refuse the whole group. Overwrite, insert, new tracks and cross-project paste are not in this slice. Undo/redo, archive fork and AAC MP4 remain actual existing paths. See ADR0032 and evidence/clipboard. I-005 stays partial. Ordinary local commit only; seven unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.26 — overwrite paste and move

Workbench Collision mode can be set to overwrite. Paste and same-track linked moves then carve each member's destination interval on existing same-kind tracks in the same project: intersecting items are split or removed, leftover fragments keep remapped sources and cropped opacity curves, later uninvolved clips are not rippled, and duration is max(old end, new ends). Default reject still collides. Insert/ripple is refused at the command and is not in this slice. Locks, incomplete closures and negative/off-grid times refuse the whole group. Affected dissolves are deleted; a pair that travels together keeps and shifts its cut. One persistent command, undo/redo, archive fork and AAC MP4 remain actual existing paths. See ADR0033 and evidence/overwrite. I-005 stays partial. Ordinary local commit only; eight unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.27 — insert paste and move

Workbench Collision mode can be set to insert, alongside reject and overwrite. Paste and same-track linked moves then split ripple tracks at the destination, shift later content by the package span, fill gaps on non-target ripple tracks, and grow duration by that span. A move vacates its source as a gap and does not ripple-close it. Mid-clip splits remap sources and opacity curves; a dissolve at the insert cut is deleted, a later dissolve is remapped onto the right remnant, and a traveling pair keeps and shifts its cut. Locked targets, locked syncLock neighbors, negative/off-grid times and absolute captions that would have to move refuse the whole group. One persistent command, undo/redo, archive fork and AAC MP4 remain actual existing paths. Ripple-delete/trim, new tracks and cross-project paste are not in this slice. See ADR0034 and evidence/insert. I-005 stays partial. Ordinary local commit only; nine unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.28 — ripple delete of a single continuous range

Workbench Ripple delete range removes one continuous closure-defined range and shifts later content on participating tracks left by L, shrinking duration by that span (unless unmoved non-ripple tracks end later). Lift/leave-gap delete, reject, overwrite and insert stay distinct. Gapped selections refuse; unselected sync-lock items that span the range keep both remnants with remapped sources; later opacity curves travel with their owners; dissolves inside the range or whose endpoints vanish are dropped, later dissolves shift. Locked members, locked sync-lock neighbors, and absolute captions that would have to move refuse the whole group. One persistent command, undo/redo, archive fork and AAC MP4 remain actual existing paths. Ripple trim, closing a move source, new tracks and cross-project paste are not in this slice. See ADR0035 and evidence/ripple-delete. I-005 stays partial. Ordinary local commit only; ten unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.29 — ripple trim (shorten only)

Workbench Ripple trim out/in shortens one selected clip plus its link closure and closes the vacated tail on participating tracks, shrinking duration by that span (unless unmoved non-ripple tracks end later). Leave-gap trim, video-only TrimClip(ripple:true), ripple delete, reject, overwrite and insert stay distinct. In-trim pins timeline start and remaps source; unselected sync-lock items that span the vacated tail keep both remnants with remapped sources; later opacity curves travel with their owners; dissolves at or after the old end shift, dissolves inside the vacated tail are dropped. Locked members, locked sync-lock neighbors, over-shorten, lengthen, and absolute captions that would have to move refuse the whole group. One persistent command, undo/redo, archive fork and AAC MP4 remain actual existing paths. Lengthening and closing a move source are not in this slice. See ADR0036 and evidence/ripple-trim. I-005 stays partial. Ordinary local commit only; eleven unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.30 — ripple close range (vacated move source)

Workbench Ripple close range closes one explicit continuous interval on participating tracks, including a vacated insert-move source hole, and shrinks duration by that span (unless unmoved non-ripple tracks end later). Insert-mode MoveClips is unchanged and still leaves the source as a gap; this is not a new move mode. Clip-id ripple delete, leave-gap delete/trim, shorten-only ripple trim, and reject/overwrite/insert stay distinct. Range and clip ids are mutually exclusive. Mid-span close keeps remapped remnants; later opacity curves travel with their owners; dissolves inside the closed interval are dropped and later cuts shift. Locked members, locked sync-lock neighbors, negative starts, and absolute captions that would have to move refuse the whole group. One persistent command, undo/redo, archive fork and AAC MP4 remain actual existing paths. Auto-close-on-move and ripple-trim lengthening are not in this slice. See ADR0037 and evidence/ripple-close. I-005 stays partial. Ordinary local commit only; twelve unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.31 — ripple trim lengthen

Workbench Ripple trim out/in lengthen grows one selected clip plus its link closure and shifts later content on participating tracks, increasing duration by that span. Shorten buttons still close the vacated tail. Leave-gap trim, video-only TrimClip(ripple:true), clip-id and range ripple delete, range close, reject, overwrite and insert stay distinct. In-lengthen pins timeline start and remaps earlier source; unselected sync-lock items that span the old end keep both remnants, with the right remnant shifted; later opacity curves travel with their owners; dissolves at or after the old end shift. Locked members, locked sync-lock neighbors, source exhaustion, over-shorten, and absolute captions that would have to move refuse the whole group. One persistent command, undo/redo, archive fork and AAC MP4 remain actual existing paths. Auto-close-on-move is not in this slice. See ADR0038 and evidence/ripple-trim-lengthen. I-005 stays partial. Ordinary local commit only; thirteen unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.32 — ignore links and groups for a single move

Workbench “Ignore links and groups this move” (or Alt held at pointer-down) sets `MoveClips.includeLinks=false` for that one command: only the explicit IDs move, a partially moved AV link is marked `allowOutOfSync`, and stored offsets are not rewritten. Default include-links, ripple trim/delete link expansion, insert-move leave-gap, explicit range close, leave-gap delete/trim, shorten and lengthen ripple trim, and reject/overwrite/insert stay distinct. Locked unmoved partners do not refuse an ignore-links move; a locked selected member still refuses the whole request. One persistent command, undo/redo, archive fork and AAC MP4 remain actual existing paths. Auto-close-on-move, caption cue-follow, marker business, new-track, cross-project bake, OS clipboard and I-006 are not in this slice. See ADR0039 and evidence/ignore-links-move. I-005 stays partial. Ordinary local commit only; fourteen unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.33 — follow clip-local captions when a host clip moves

Workbench “Anchor selected cue to covering clip” marks a cue clipLocal. MoveClips (including insert-move later hosts and ignore-links of that host) then translates the cue with the clip; stored clip-local range, text, and absolute siblings stay put. New and imported cues stay absolute until anchored. Source anchors, ripple/insert-paste cue crop/split, and MP4 text burn-in remain refused; sidecar VTT export carries the followed times. Leave-gap, ripple delete/close, shorten and lengthen ripple trim, reject/overwrite/insert, includeLinks=false, and insert-move leave-gap stay distinct. One persistent move command, undo/redo, archive fork and sidecar export are actual existing paths. Auto-close-on-move, new-track, cross-project bake, OS clipboard, marker business and I-006 are not in this slice. See ADR0040 and evidence/caption-follow-move. I-005 stays partial. Ordinary local commit only; fifteen unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.34 — crop and shift captions across a ripple or insert interval

Ripple delete, range close, ripple trim, and insert paste or insert-move now crop, split, and shift absolute cues across that interval and rebind clipLocal remnants to a covering host. A cue wholly inside a closed interval is dropped as crop-to-empty and returns on undo; remnants without a covering host refuse the whole command. Insert-move still leaves a source gap and does not split clipLocal cues on an unsplit moving host. Source anchors and a locked caption track still refuse the whole group. MP4 text burn-in stays refused; sidecar VTT is the export path. Leave-gap, single-range ripple delete/close, shorten and lengthen ripple trim, reject/overwrite/insert, includeLinks=false, insert-move leave-gap, and MoveClips caption follow stay distinct. One persistent command, undo/redo, archive fork and sidecar export are actual existing paths. Auto-close-on-move, new-track, cross-project bake, OS clipboard, marker business and I-006 are not in this slice. See ADR0041 and evidence/caption-interval. I-005 stays partial; I-010 remainingAcceptance is unchanged. Ordinary local commit only; sixteen unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.35 — new and imported cues default to clipLocal when uniquely covered

Add cue or import a range that sits fully on a unique covering clip now anchors it clipLocal in the same SetCaptions, so a later MoveClips of that host translates the cue; a cue in a gap or spanning a cut stays absolute. Make selected cue absolute keeps that ID at authored times and is not re-anchored. Source anchors and MP4 text burn-in stay refused; sidecar VTT is the export path. Leave-gap, single-range ripple delete/close, shorten and lengthen ripple trim, reject/overwrite/insert, includeLinks=false, insert-move leave-gap, MoveClips caption follow, and interval crop/split/shift stay distinct. One persistent command, undo/redo, archive fork and sidecar export are actual existing paths. Auto-close-on-move, new-track, cross-project bake, OS clipboard, marker business and I-006 are not in this slice. See ADR0042 and evidence/caption-default-cliplocal. I-005 stays partial; I-010 remainingAcceptance is unchanged. Ordinary local commit only; seventeen unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.36 — admit sequence markers that follow or ripple

SetMarkers writes sequence markers. New markers default to absolute with ripple=false and stay put when later content shifts; Anchor selected marker to covering clip or Add marker on covering clip attaches a unique host, and that marker follows the host on MoveClips. ripple=true absolute markers use the same interval crop/split/shift as captions; a marker wholly inside a closed range is dropped as a crop-to-empty and comes back on undo. Admitted markers are snap targets. Labels are not burned into preview or export MP4. Leave-gap, single-range ripple delete/close, shorten and lengthen ripple trim, reject/overwrite/insert, includeLinks=false, insert-move leave-gap, caption default clipLocal, follow, and interval crop/split/shift stay distinct. One persistent command, undo/redo, archive fork and export are actual existing paths. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source caption anchors and I-006 are not in this slice. See ADR0043 and evidence/marker-edit. I-005 stays partial; I-010 remainingAcceptance is unchanged. Ordinary local commit only; eighteen unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.37 — explicit source caption anchors reproject with their host

A selected cue can be anchored to the source window of its unique covering clip. The stored range is the offset from the host `sourceRange.start` under a linear time map; the timeline range stays the projection of that window. Source cues reproject on already-opened MoveClips, overwrite, paste, insert-move, and ripple delete/close/trim when a unique same-stream host still covers that window (including a split remnant). An interval that would uncover or crop a source cue refuses the whole command instead of silently dropping or rewriting text. New and imported uniquely covered cues still default to clipLocal, not source; made-absolute cues stay at authored times. Styles, words, speakers, and MP4 / preview burn-in remain refused. Leave-gap, single-range ripple delete/close, shorten and lengthen ripple trim, reject/overwrite/insert, includeLinks=false, insert-move leave-gap, caption default clipLocal / follow / interval crop, and marker absolute default / clipLocal follow / ripple interval stay distinct. One persistent command, undo/redo, archive fork, and sidecar export are actual existing paths. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, 1000 random NLE undo, source-interval crop, and I-006 are not in this slice. See ADR0044 and evidence/caption-source-anchor. I-005 and I-010 stay partial. Ordinary local commit only; nineteen unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.38 — 1000 seeded random undos of already-opened NLE commands

One thousand seeded random sequences over already-opened I-005 commands (reject/overwrite/insert MoveClips, includeLinks true or false, ripple delete/close/trim, SetCaptions, SetMarkers) undo to an equal document content hash. Locked hosts and negative starts refuse the whole group and leave captions and markers in place. Source-anchored cues are never silently dropped. A short workbench path adds a default clipLocal cue and an absolute marker, commits one host move, undoes and redoes that command, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Leave-gap, explicit-range ripple close, insert-move leave-gap, caption default/follow/interval/source-window, and marker absolute default / clipLocal follow / ripple interval stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, source-interval crop, and I-006 are not in this slice. See ADR0045 and evidence/nle-random-undo. I-005 and I-010 stay partial. Ordinary local commit only; twenty unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.39 — already-opened section-3 positive/negative matrix

A packed A/B/C fixture scaled from the s3 450-frame examples onto the 3-second local video (÷5, still on the 30 fps grid) qualifies already-opened commands against the table’s positive geometry and stated refusals: reject move collision and negative start, split source remapping, insert paste including a spanning synced audio split, overwrite, leave-gap lift, ripple close of R=[120,180), ordinary leave-gap trim, ripple trim in/out, includeLinks offset / ignore-links / unlink, copy A+C preserving the relative gap, and caption/marker follow with REF_NOT_FOUND when lifting a clipLocal-marker host. Insert-move still leaves a source gap; auto-close is not a MoveClips mode. A workbench path splits A/B/C, previews a colliding +6-frame move, ripple-trims A, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Split/trim with captions still refuse CAPTION_SYNC_EDIT_NOT_IMPLEMENTED; the table’s 0.02s offset is off the video grid. Not the full section-3 matrix, new-track, cross-project bake, OS clipboard, field-aware inverse, marker sidecar formats, or I-006. See ADR0046 and evidence/s3-opened-matrix. I-005 and I-010 stay partial. Ordinary local commit only; twenty-one unpublished ancestors preserved, no push or remote diagnosis.


## Increment1.40 — caption-aware SplitClip and leave-gap TrimClip

SplitClip and ordinary TrimClip(ripple:false) now keep, rebind, or split-to-absolute captions and markers instead of refusing CAPTION_SYNC_EDIT_NOT_IMPLEMENTED. Split never auto-splits cue text; a uniquely covered clipLocal or source cue rebinds to the remnant, a spanning clipLocal becomes absolute, and a spanning or uncovering source cue is whole-group ANCHOR_OUT_OF_RANGE. Leave-gap trim does not shift later content: the portion still on the host stays clipLocal at the same sequence times, and the vacated gap keeps an absolute remnant with the same text. Linked AV members split and trim together. Ripple TrimClip with captions still refuses. A workbench path extracts persistent audio, adds a default clipLocal cue, splits, leave-gap trims, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption default/follow/interval/source-window, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, source-interval crop, marker sidecar formats, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0047 and evidence/caption-split-trim. I-005 and I-010 stay partial. Ordinary local commit only; twenty-two unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.41 — caption-aware ripple TrimClip

On a video-only timeline, TrimClip(ripple:true) now reuses the same caption and marker interval crop/split/shift as RippleTrimClip, instead of refusing CAPTION_SYNC_EDIT_NOT_IMPLEMENTED. Later content still closes or opens after the old out point; an in trim still pins start. A spanning cue keeps its text; source uncover is whole-group ANCHOR_OUT_OF_RANGE. Leave-gap TrimClip still does not shift later content. Linked-audio ripple trim still refuses CAPTION_SYNC_EDIT_NOT_IMPLEMENTED. A workbench path imports video only, adds a spanning cue, ripple-trims 15 frames, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, source-interval crop, marker sidecar formats, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0048 and evidence/caption-ripple-trim. I-005 and I-010 stay partial. Ordinary local commit only; twenty-three unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.42 — caption-aware linked-audio ripple TrimClip

TrimClip(ripple:true) on a timeline that already has a persistent audio track now delegates to the existing RippleTrimClip path, so linked members ripple together and captions and markers use the same interval crop/split/shift, instead of refusing CAPTION_SYNC_EDIT_NOT_IMPLEMENTED or being rewritten as LINKED_RIPPLE_NOT_IMPLEMENTED. Leave-gap TrimClip still does not shift later content. MoveClip with captions and linked ripple DeleteClip stay refused. A workbench path extracts persistent audio, adds a spanning cue, ripple-trims 15 frames, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only ripple TrimClip, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, source-interval crop, marker sidecar formats, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0049 and evidence/caption-linked-ripple-trim. I-005 and I-010 stay partial. Ordinary local commit only; twenty-four unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.43 — caption-aware ripple DeleteClip (video-only and linked audio)

DeleteClip(ripple:true) now applies the same caption and marker interval crop/split/shift as RippleDeleteClips, instead of refusing CAPTION_SYNC_EDIT_NOT_IMPLEMENTED or, on a persistent-audio timeline, being rewritten as LINKED_RIPPLE_NOT_IMPLEMENTED. Linked members are removed together and later content closes the vacated interval. A spanning cue keeps its text; source uncover is whole-group ANCHOR_OUT_OF_RANGE. Leave-gap DeleteClip with captions still refuses CAPTION_SYNC_EDIT_NOT_IMPLEMENTED. MoveClip with captions stays refused. A workbench path extracts persistent audio, splits at one second, adds a spanning cue, ripple-deletes the left pair, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap trim, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only and linked-audio ripple TrimClip, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, source-interval crop, marker sidecar formats, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0050 and evidence/caption-linked-ripple-delete. I-005 and I-010 stay partial. Ordinary local commit only; twenty-five unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.44 — caption-aware leave-gap DeleteClip

DeleteClip(ripple:false) with captions no longer refuses CAPTION_SYNC_EDIT_NOT_IMPLEMENTED. Later content is not shifted. A clipLocal cue bound to a removed host becomes an absolute remnant at the same times with the same text; later cues keep their times. On a persistent-audio timeline, linked members are removed together and the vacated hole is left on both tracks. Source uncover is whole-group ANCHOR_OUT_OF_RANGE. MoveClip with captions stays refused. Ripple DeleteClip is unchanged from Increment 1.43. A workbench path extracts persistent audio, splits at one second, adds a left-hand cue, uses Delete (leave gap), then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap trim, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only and linked-audio ripple TrimClip, caption-aware ripple DeleteClip, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, source-interval crop, marker sidecar formats, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0051 and evidence/caption-leave-gap-delete. I-005 and I-010 stay partial. Ordinary local commit only; twenty-six unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.45 — caption-aware MoveClip

MoveClip with captions no longer refuses CAPTION_SYNC_EDIT_NOT_IMPLEMENTED. The selected clip, and on a persistent-audio timeline its linked members, translate together; clipLocal cues and markers follow the host, absolute cues stay at authored times, and source-anchored cues reproject when the source window still covers them. The vacated source is left as a gap; this is not auto-close-on-move. A colliding destination is whole-group COLLISION. A workbench path extracts persistent audio, adds a clipLocal cue, moves 15 frames, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap trim/delete, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only and linked-audio ripple TrimClip, caption-aware ripple and leave-gap DeleteClip, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, source-interval crop, marker sidecar formats, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0052 and evidence/caption-move-clip. I-005 and I-010 stay partial. Ordinary local commit only; twenty-seven unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.46 — caption-aware LiftClips (leave-gap cut)

LiftClips (Cut) with captions no longer leaves a dangling clipLocal host as REF_NOT_FOUND. The admitted link-and-selection closure is still lifted together and the vacated source stays a gap; a clipLocal cue whose host is cut becomes an absolute remnant at its original times with the same text, later cues are not shifted, and absolute cues stay put. A source-anchored cue whose host is lifted is whole-group ANCHOR_OUT_OF_RANGE, matching leave-gap DeleteClip uncover. Lifting a clipLocal-marker host remains REF_NOT_FOUND; captions do not enter the internal clipboard package, so paste does not copy or move them. A workbench path extracts persistent audio, splits, adds a clipLocal cue, cuts the selection, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap trim/delete, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption-aware MoveClip, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only and linked-audio ripple TrimClip, caption-aware ripple and leave-gap DeleteClip, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, field-aware inverse, source-interval crop, marker sidecar formats, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0053 and evidence/caption-lift-clips. I-005 and I-010 stay partial. Ordinary local commit only; twenty-eight unpublished ancestors preserved, no push or remote diagnosis.


## Increment1.47 — field-aware invert of a prior command

A named invert of a prior committed command that is not the undo tip now restores only that command's content write set when those fields still match the command's after-image; a later edit to any of those fields, or a tip / undo / redo / invert target, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot; versions and revisions are concurrency clocks and are reallocated on the invert commit, with no new table. A workbench path adds two left-side captions, moves an uninvolved right remnant, inverts the later SetCaptions (the extra cue is removed; the earlier cue, the moved remnant, and later markers stay), then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap trim/delete, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption-aware MoveClip and LiftClips/Cut, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only and linked-audio ripple TrimClip, caption-aware ripple and leave-gap DeleteClip, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a full invert matrix for every command, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0054 and evidence/field-invert. I-005 and I-010 stay partial. Ordinary local commit only; twenty-nine unpublished ancestors preserved, no push or remote diagnosis.


## Increment1.48 — caption-aware overwrite move and paste

Overwrite move and overwrite paste with captions no longer leave a dangling clipLocal host after the destination is carved. Uniquely covered destination cues rebind to a remnant; otherwise the whole cue stays at its authored times as an absolute remnant with the same text, and later cues are not shifted. A followed cue on the moving clip still follows the host; if it would occupy the same times as a dest remnant the command is whole-group CAPTION_OVERLAP. Overwrite paste may rebind a uniquely covered dest cue onto the pasted clip. A source-anchored cue whose window is uncovered or cropped remains ANCHOR_OUT_OF_RANGE. A workbench path extracts persistent audio, splits, adds left / carved / remnant cues, uses Collision mode overwrite and a multi-select move, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered leave-gap trim/delete, explicit-range ripple close, insert-move leave-gap, includeLinks=false, caption-aware MoveClip and LiftClips/Cut, field-aware invert, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only and linked-audio ripple TrimClip, caption-aware ripple and leave-gap DeleteClip, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0055 and evidence/caption-overwrite. I-005 and I-010 stay partial. Ordinary local commit only; thirty unpublished ancestors preserved, no push or remote diagnosis.
## Increment1.49 — SetTrackState locked (track lock / unlock)

Workbench SetTrackState can lock or unlock an existing video, audio, or caption track. The track's own lock does not block this meta-op, so a locked track can still be unlocked. Setting the same value is a no-op; a missing track is TRACK_NOT_FOUND. After a video track is locked, opened clip edits refuse FIELD_LOCKED as a whole group and do not drop or retarget captions; SetCaptions on an unlocked caption track still applies. Locking the caption track refuses a changing SetCaptions with FIELD_LOCKED. Locking a persistent audio track refuses SetAudioTrackState mute/solo and clip edits on that track until it is unlocked. A workbench path extracts persistent audio, adds a clipLocal cue, locks the video track, undoes and redoes the lock, confirms a move is refused, unlocks, then moves the host so the cue follows, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Video and caption mute/solo remain FEATURE_NOT_IMPLEMENTED at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled here. Already-delivered insert-move leave-gap, explicit-range ripple close, includeLinks=false, leave-gap and ripple trim/delete, caption-aware MoveClip and LiftClips/Cut, field-aware invert, caption-aware overwrite, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, video-only and linked-audio ripple TrimClip, caption-aware ripple and leave-gap DeleteClip, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0056 and evidence/track-lock. I-005 and I-010 stay partial. Ordinary local commit only; thirty-one unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.50 — field-aware invert of a prior SetMarkers command

Field-aware invert now has an official persist path for a prior non-tip SetMarkers command: only that command's marker write set is restored when those fields still match the command's after-image; earlier captions and an unrelated leave-gap MoveClip of a non-host remnant stay. A later edit to those markers, a followed clipLocal marker that has already moved with its host, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path extracts persistent audio, splits, adds a clipLocal cue, adds an absolute marker, moves the right remnant, inverts the SetMarkers command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Already-delivered SetTrackState locked, overwrite, LiftClips/Cut, MoveClip, Delete/Trim, insert-move leave-gap, includeLinks=false, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, video/caption mute/solo, syncLock, and I-006 are not in this slice. See ADR0057 and evidence/field-invert-markers. I-005 and I-010 stay partial. Ordinary local commit only; thirty-two unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.51 — caption-aware GroupClips / UngroupClips

Grouping two captioned remnants does not retarget or drop their cues. A later default MoveClips of one member expands the selection group, translates both clips together, leaves a source gap, and follows clipLocal cues (and clipLocal markers); absolute cues stay put and still-covered source cues reproject. includeLinks=false still moves only the explicit IDs. After ungroup, a later move of one member leaves the other cue in place. An ungrouped half-step that would overlap a neighbor remains whole-group COLLISION; the same half-step after grouping succeeds. Lifting a clipLocal-marker host remains REF_NOT_FOUND. A workbench path extracts persistent audio, splits, adds left and right cues, groups the two remnants, commits a multi-select move, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip and is not silently expanded. Already-delivered insert-move leave-gap, SetTrackState locked, field-aware invert including SetMarkers, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, video/caption mute/solo, syncLock, and I-006 are not in this slice. See ADR0058 and evidence/caption-group-clips. I-005 and I-010 stay partial. Ordinary local commit only; thirty-three unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.52 — field-aware invert of a prior GroupClips command

Field-aware invert now has an official persist path for a prior non-tip GroupClips or UngroupClips command: only that command's grouping write set is restored when those fields still match the command's after-image. A later default MoveClips of the group that only changes geometry does not conflict, so invert dissolves the group and keeps the moved remnants and already-followed cues. A later UngroupClips of the same group, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Invert of a prior UngroupClips after a later single-member move restores only the group membership. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path extracts persistent audio, splits, adds left and right cues, groups the remnants, commits a multi-select move, inverts the GroupClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Already-delivered caption-aware grouping, insert-move leave-gap, SetTrackState locked, invert of SetCaptions and SetMarkers, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, video/caption mute/solo, syncLock, and I-006 are not in this slice. See ADR0059 and evidence/field-invert-group. I-005 and I-010 stay partial. Ordinary local commit only; thirty-four unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.53 — field-aware invert of a prior SetTrackState command

Field-aware invert now has an official persist path for a prior non-tip SetTrackState command: only that command's lock write set is restored when those fields still match the command's after-image. A later leave-gap move that only changes geometry does not conflict, so invert of a caption-track lock unlocks the track and keeps the moved remnants and already-followed cues. Invert of a later unlock after a leave-gap move restores only the lock. A later lock change of the same track, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path extracts persistent audio, splits, adds left and right cues, locks the caption track, commits a single-clip leave-gap move, inverts the SetTrackState command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered SetTrackState locked, caption-aware grouping, invert of SetCaptions / SetMarkers / GroupClips, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0060 and evidence/field-invert-track-lock. I-005 and I-010 stay partial. Ordinary local commit only; thirty-five unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.54 — field-aware invert of a prior SetAudioTrackState command

Field-aware invert now has an official persist path for a prior non-tip SetAudioTrackState command: only that command's audio-state write set is restored when those fields still match the command's after-image. A later leave-gap move that only changes geometry does not conflict, so invert of a mute unmutes the track and keeps the moved remnants and already-followed cues. Invert of a later unmute after a leave-gap move restores only the mute. A later mute change of the same track, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path extracts persistent audio, splits, adds left and right cues, mutes the audio track, commits a single-clip leave-gap move, inverts the SetAudioTrackState command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0061 and evidence/field-invert-audio-mute. I-005 and I-010 stay partial. Ordinary local commit only; thirty-six unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.55 — field-aware invert of a prior UnlinkAudioVideo command

Field-aware invert now has an official persist path for a prior non-tip UnlinkAudioVideo or LinkAudioVideo command: only that command's link write set is restored when those fields still match the command's after-image. A later leave-gap move that translates both unlinked members by the same amount does not conflict, so invert of an unlink restores the link and keeps the moved remnants and already-followed cues. Invert of a later relink after a linked move restores only the unlink. A later relink of the same pair, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Invert of an unlink after a diverging move that breaks the recorded offset is refused by existing validation as LINK_OFFSET_MISMATCH and does not roll the database back; that error code is not retargeted. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path extracts persistent audio, splits, adds left and right cues, unlinks the right pair, commits a multi-select leave-gap move of both unlinked remnants, inverts the UnlinkAudioVideo command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0062 and evidence/field-invert-unlink. I-005 and I-010 stay partial. Ordinary local commit only; thirty-seven unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.56 — field-aware invert of a prior ExtractAudioClip command

Field-aware invert now has an official persist path for a prior non-tip ExtractAudioClip command: only that command's extract write set is restored when those fields still match the command's after-image. A later leave-gap move of an uninvolved remnant does not conflict, so invert removes the extracted audio and link and keeps the moved remnants and already-followed cues. A later linked move of the extracted host, a later mute of the new audio track, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Invert's version indexer and bumper skip source refs so they cannot overwrite an asset or rewrite clip source.version. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path splits, adds left and right cues, extracts persistent audio from the left remnant, commits a single-clip leave-gap move of the uninvolved right remnant, inverts the ExtractAudioClip command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0063 and evidence/field-invert-extract. I-005 and I-010 stay partial. Ordinary local commit only; thirty-eight unpublished ancestors preserved, no push or remote diagnosis.

## Increment1.57 — field-aware invert of a prior SplitClip command

Field-aware invert now has an official persist path for a prior non-tip SplitClip command: only that command's split write set is restored when those fields still match the command's after-image. A later leave-gap move of an uninvolved remnant does not conflict, so invert restores the split host, removes the new remnant, and keeps the moved remnants and already-followed cues. A later leave-gap move of a split product, a later out-trim of the left remnant that changes a recorded duration numerator, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path first splits at 2s, adds left and right cues, splits the left remnant at 1s, commits a single-clip leave-gap move of the uninvolved right remnant, inverts the second SplitClip command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0064 and evidence/field-invert-split. I-005 and I-010 stay partial. Ordinary local commit only; the already-pushed parent 98b7c97 and unpublished 54f62c06 are preserved, no push or remote diagnosis.

## Increment1.58 — field-aware invert of a prior leave-gap TrimClip command

Field-aware invert now has an official persist path for a prior non-tip leave-gap TrimClip command: only that command's trim write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the pre-trim duration, removes the leave-gap filler, and keeps the later markers and unmoved cues. On a video-only timeline, a later leave-gap move of a non-adjacent remnant also does not conflict and keeps already-followed cues. A later out-trim that changes a recorded duration numerator, a later leave-gap move of an adjacent remnant, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path extracts persistent audio so the Trim button is leave-gap, first splits at 2s, adds left and right cues, splits the left remnant at 1s, leave-gap out-trims the left remnant by 0.5s, adds a later marker, inverts the TrimClip command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered trim, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0065 and evidence/field-invert-trim. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06 and 6f3e4a56 are preserved, no push or remote diagnosis.

## Increment1.59 — field-aware invert of a prior RippleTrimClip command

Field-aware invert now has an official persist path for a prior non-tip RippleTrimClip command: only that command's ripple-trim write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert of a rightmost ripple out-trim restores the pre-trim duration and keeps the later markers and unmoved cues. Invert of a left ripple out-trim after a later marker also restores later starts and already-shifted cues. A later out-trim that changes a recorded duration numerator, a later leave-gap move of a remnant whose start was shifted by the ripple, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path splits at 1s, adds left and right cues, ripple out-trims the right remnant by 0.5s, adds a later marker, inverts the RippleTrimClip command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple trim, leave-gap trim, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0066 and evidence/field-invert-ripple-trim. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56 and 59a32d36 are preserved, no push or remote diagnosis.

## Increment1.60 — field-aware invert of a prior RippleDeleteClips command

Field-aware invert now has an official persist path for a prior non-tip RippleDeleteClips of a rightmost remnant: only that command's delete write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the deleted remnant and its cue and keeps the later markers and unmoved earlier cues. A later out-trim of the uninvolved left remnant, or a later text edit of the uninvolved left cue, also does not conflict. A later leave-gap move of a remnant whose start was shifted by a ripple delete of an earlier remnant, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Invert of a non-last ripple delete that must reinsert an earlier clip is not this slice's official success path; admission can refuse IMPLICIT_GAP because the restored item is appended after later remnants, and this slice does not change insertion order or retarget that code. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. A workbench path splits at 1s, adds left and right cues, ripple-deletes the right remnant, adds a later marker, inverts the RippleDeleteClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0067 and evidence/field-invert-ripple-delete. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36 and deea2310 are preserved, no push or remote diagnosis.

## Increment1.61 — field-aware invert of a prior leave-gap DeleteClip command

Field-aware invert now has an official persist path for a prior non-tip leave-gap DeleteClip of a rightmost remnant: only that command's delete write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the deleted remnant, rebinds the leftover stay cue to clipLocal on that host, and keeps the later markers and unmoved earlier cues. A later text edit of the uninvolved left cue, or of the leftover stay remnant, also does not conflict; invert keeps the new text. A later leave-gap out-trim of the remaining left remnant remints the gap filler written by the delete, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Invert of a non-last leave-gap delete that must reinsert an earlier clip is not this slice's official success path; admission can refuse IMPLICIT_GAP because the restored item is appended after later remnants, and this slice does not change insertion order or retarget that code. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra. A workbench path first extracts persistent audio so the Delete button is leave-gap, splits at 1s, adds left and right cues, leave-gap deletes the right remnant, adds a later marker, inverts the DeleteClip command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The SDK persist path issues DeleteClip with the default ripple:false and does not require extract. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0068 and evidence/field-invert-leave-gap-delete. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310 and 30f92009 are preserved, no push or remote diagnosis.

## Increment1.62 — field-aware invert of a prior leave-gap MoveClip command

Field-aware invert now has an official persist path for a prior non-tip leave-gap MoveClip of a right remnant: only that command's move write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the remnant's start and the followed stay cue and keeps the later markers and unmoved earlier cues. A later text edit of the followed stay cue, or of the uninvolved left cue, also does not conflict; invert keeps the new text. A later second leave-gap move of the same remnant, a later leave-gap out-trim of the remaining left remnant that remints the vacated gap filler, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. This later-left-trim conflict is the same filler-remint bound already documented for leave-gap delete invert. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP. A workbench path splits at 1s, adds left and right cues, leave-gap moves the right remnant by 1s with the single-clip Move button, adds a later marker, inverts the MoveClip command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required for this path. The single-clip Move button stays MoveClip and does not silently take an unlinked audio partner or expand into a group move. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip, caption-aware grouping, insert-move leave-gap, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0069 and evidence/field-invert-move-clip. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009 and 95d34b33 are preserved, no push or remote diagnosis.

## Increment1.63 — field-aware invert of a prior LiftClips command

Field-aware invert now has an official persist path for a prior non-tip LiftClips of a rightmost remnant: only that command's lift write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the lifted remnant, rebinds the leftover stay cue to clipLocal on that host, and keeps the later markers and unmoved earlier cues. A later text edit of the uninvolved left cue, or of the leftover stay remnant, also does not conflict; invert keeps the new text. A later leave-gap out-trim of the remaining left remnant remints the gap filler written by the lift, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. This later-left-trim conflict is the same filler-remint bound already documented for leave-gap delete invert and leave-gap MoveClip invert. Invert of a non-last LiftClips that must reinsert an earlier clip is not this slice's official success path; admission can refuse IMPLICIT_GAP because the restored item is appended after later remnants, and this slice does not change insertion order or retarget that code. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra. A workbench path splits at 1s, adds left and right cues, multi-selects the right remnant, cuts it with the existing Cut button, adds a later marker, inverts the LiftClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required: Cut is leave-gap even without persistent audio. Captions still do not enter the internal clipboard package, and this slice does not claim that invert clears that package. The single-clip Move button stays MoveClip. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Lifting a clipLocal-marker host remains REF_NOT_FOUND. An uncovering or cropping interval remains ANCHOR_OUT_OF_RANGE. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0070 and evidence/field-invert-lift-clips. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33 and e18b8a39 are preserved, no push or remote diagnosis.

## Increment1.64 — field-aware invert of a prior leave-gap MoveClips command

Field-aware invert now has an official persist path for a prior non-tip reject-mode leave-gap MoveClips of both remnants of a split: only that command's move write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores both remnant starts and both followed cues and keeps the later markers. A later text edit of either followed cue also does not conflict; invert keeps the new text. A later second leave-gap MoveClips of the same remnants, a later leave-gap out-trim that remints a vacated gap filler, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. This later-left-trim conflict is the same filler-remint bound already documented for leave-gap delete, leave-gap MoveClip, and LiftClips invert. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize overwrite/insert modes, includeLinks=false invert, or auto-close of the vacated source gap. A workbench path splits at 1s, adds left and right cues, multi-selects both remnants, previews and commits a +1s reject-mode MoveClips, adds a later marker, inverts the MoveClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The native multi-move ghost of a caption-bearing timeline also refuses CAPTION_RENDER_POLICY_NOT_IMPLEMENTED, but that refusal does not block committing the pending gesture. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0071 and evidence/field-invert-move-clips. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39 and 0cb53944 are preserved, no push or remote diagnosis.

## Increment1.65 — field-aware invert of a prior overwrite-mode MoveClips command

Field-aware invert now has an official persist path for a prior non-tip overwrite-mode MoveClips of a left remnant onto a right remnant: only that command's overwrite write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the moving remnant's start, restores the carved destination's start and duration, rebinds the leftover carved cue to clipLocal, restores the followed moving cue, and keeps the later markers. A later text edit of the leftover carved cue, or of the followed moving cue, also does not conflict; invert keeps the new text. A later leave-gap out-trim of the carved destination remnant, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize insert-mode MoveClips invert, includeLinks=false invert, overwrite PasteClips invert, or auto-close of a vacated source gap. A workbench path splits at 1s, adds hello, carved, and stay cues, sets collision mode to overwrite, multi-selects the left remnant, previews and commits a +1s overwrite MoveClips, adds a later marker, inverts the MoveClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The native multi-move ghost of a caption-bearing timeline also refuses CAPTION_RENDER_POLICY_NOT_IMPLEMENTED, but that refusal does not block committing the pending gesture. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0072 and evidence/field-invert-overwrite-move. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944 and b3597160 are preserved, no push or remote diagnosis.

## Increment1.66 — field-aware invert of a prior insert-mode MoveClips command

Field-aware invert now has an official persist path for a prior non-tip insert-mode MoveClips of a left remnant by +1s: only that command's insert write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the moving remnant's start, restores the destination-shifted remnant's start, restores sequence duration 3, restores both followed cues, and keeps the later markers. A later text edit of the followed destination-shifted cue, or of the followed moving cue, also does not conflict; invert keeps the new text. Insert still leaves a vacated source gap and does not auto-close it. A later leave-gap MoveClip of the destination-shifted remnant, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize includeLinks=false invert, overwrite or insert PasteClips invert, SetDissolve invert, or auto-close of a vacated source gap. A workbench path splits at 1s, adds hello and stay cues, sets collision mode to insert, multi-selects the left remnant, previews and commits a +1s insert MoveClips, adds a later marker, inverts the MoveClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The native multi-move ghost of a caption-bearing timeline also refuses CAPTION_RENDER_POLICY_NOT_IMPLEMENTED, but that refusal does not block committing the pending gesture. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0073 and evidence/field-invert-insert-move. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160 and c4f58904 are preserved, no push or remote diagnosis.

## Increment1.67 — field-aware invert of a prior includeLinks=false MoveClips command

Field-aware invert now has an official persist path for a prior non-tip reject-mode includeLinks=false MoveClips of a video host by +1s: only that command's ignore-links write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the moving host's start, leaves the unmoved audio partner at its original start, restores link policy preserve and the stored offset, restores sequence duration 3, restores the followed hello cue, and keeps the later markers and the unmoved absolute stay cue. A later text edit of the unmoved stay cue, or of the followed hello cue, also does not conflict; invert keeps the new text. A later +0.5s includeLinks=false move of the same host, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. A later second +1s ignore-links move would slide the followed hello onto the unmoved stay and still refuse CAPTION_OVERLAP; official conflict therefore uses the +0.5s move or tip invert. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize overwrite or insert PasteClips invert, SetDissolve invert, or auto-close of a vacated source gap. A workbench path adds a hello cue, extracts persistent audio, adds a stay cue and makes it absolute, checks Ignore links and groups this move, multi-selects the video host, previews and commits a +1s includeLinks=false MoveClips, adds a later marker, inverts the MoveClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. The native multi-move ghost of a caption-bearing timeline also refuses CAPTION_RENDER_POLICY_NOT_IMPLEMENTED, but that refusal does not block committing the pending gesture. Extract is required so a linked audio partner exists. The single-clip Move button stays MoveClip and is not used on this path. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. A move that would overlap a followed cue and an unmoved absolute cue remains CAPTION_OVERLAP. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0074 and evidence/field-invert-ignore-links-move. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904 and 55b474c4 are preserved, no push or remote diagnosis.

## Increment1.68 — field-aware invert of a prior overwrite-mode PasteClips command

Field-aware invert now has an official persist path for a prior non-tip overwrite-mode PasteClips of a copied left remnant onto a right remnant at 1s: only that command's overwrite-paste write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert removes the pasted clip, restores the carved destination's start and duration, rebinds the leftover carved cue to clipLocal on that host, keeps the unmoved left remnant and its followed hello cue, and keeps the later markers. A later text edit of the leftover carved cue, or of the unmoved stay cue, also does not conflict; invert keeps the new text. A later leave-gap MoveClip of the carved destination remnant, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. A later leave-gap out-trim of that remnant is not this slice's official conflict path, because it can change unrecorded sourceRange canonicity without being seen as a write-set conflict. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize insert PasteClips invert, SetDissolve invert, or auto-close of a vacated source gap. A workbench path splits at 1s, adds hello, carved, and stay cues, copies the left remnant, sets collision mode to overwrite, pastes at 1s, adds a later marker, inverts the PasteClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard; invert does not claim to clear that package. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0075 and evidence/field-invert-overwrite-paste. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4 and 335c222f are preserved, no push or remote diagnosis.

## Increment1.69 — field-aware invert of a prior insert-mode PasteClips command

Field-aware invert now has an official persist path for a prior non-tip insert-mode PasteClips of a copied left remnant at the 1s cut: only that command's insert-paste write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert removes the pasted clip, restores the dest-shifted right remnant's start and the sequence duration, restores the followed stay cue, keeps the unmoved left remnant and its followed hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Insert paste still grows sequence duration by the package span and does not remove or vacate the source left remnant. A later leave-gap MoveClip of the dest-shifted right remnant, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert, SetDissolve invert, or auto-close of a vacated source gap. A workbench path splits at 1s, adds hello and stay cues, copies the left remnant, sets collision mode to insert, pastes at 1s, adds a later marker, inverts the PasteClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard; invert does not claim to clear that package. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0076 and evidence/field-invert-insert-paste. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f and 9ad68709 are preserved, no push or remote diagnosis.

## Increment1.70 — field-aware invert of a prior SetDissolve command

Field-aware invert now has an official persist path for a prior non-tip SetDissolve of a left remnant onto the adjacent right remnant at the 1s cut with 6-frame handles: only that command's dissolve write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert removes the dissolve, keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. A later SetDissolve rewrite of the same pair, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. A later leave-gap MoveClip of a dissolve host is not this slice's official conflict path, because that topology edit stays TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL while the dissolve exists. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert, RemoveDissolve invert, or auto-close of a vacated source gap. Invert's post-apply version bump now also mints a new sequence version when clock-stripped transitions change, because sequence fingerprints already close those children; without that bump, a persist-path invert after a later marker edit refused IMMUTABLE_VERSION_CONFLICT. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, sets a 6-frame VIDEO dissolve, adds a later marker, inverts the SetDissolve command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0077 and evidence/field-invert-set-dissolve. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709 and 1ed94974 are preserved, no push or remote diagnosis.

## Increment1.71 — field-aware invert of a prior RemoveDissolve command

Field-aware invert now has an official persist path for a prior non-tip RemoveDissolve of a 6-frame VIDEO dissolve at the 1s cut: only that command's removal write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores the dissolve (cut at 1s, 6-frame handles), keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip is whole-group UNDO_CONFLICT and does not roll the database back. A later SetDissolve of the same pair after removal is not this slice's official conflict path, because it mints a new transition id so fieldInvertConflicts stays false, and invert then refuses TRANSITION_WINDOW_OVERLAP; a later leave-gap MoveClip after removal likewise stays a non-conflict at the write set and invert then refuses TRANSITION_NOT_ADJACENT. This slice does not retarget those error codes. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert or auto-close of a vacated source gap. Invert still mints a new sequence version when clock-stripped transitions change; this slice does not retarget IMMUTABLE_VERSION_CONFLICT. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, sets a 6-frame VIDEO dissolve, removes it, adds a later marker, inverts the RemoveDissolve command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0078 and evidence/field-invert-remove-dissolve. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974 and 6a9b4baf are preserved, no push or remote diagnosis.

## Increment1.72 — field-aware invert of a prior SetOpacityKeyframe command

Field-aware invert now has an official persist path for a prior non-tip SetOpacityKeyframe of the left remnant at local time 0 with value 0.5 and linear interpolation: only that command's opacity-keyframe write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert removes the opacity effect from the left remnant, keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. A later SetOpacityKeyframe rewrite at the same local time, or invert of the tip, is whole-group UNDO_CONFLICT and does not roll the database back. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert, RemoveOpacityKeyframe invert, SetClipOpacity invert, or auto-close of a vacated source gap. Invert still mints a new sequence version when clock-stripped transitions change; this slice does not retarget IMMUTABLE_VERSION_CONFLICT. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, enters clip opacity 0.5 and local frame 0, sets a linear opacity keyframe, adds a later marker, inverts the SetOpacityKeyframe command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. Marker sidecar formats stay closed because the original specification has no first official format; this slice does not invent one. See ADR0079 and evidence/field-invert-set-opacity-keyframe. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf and 97cc3e73 are preserved, no push or remote diagnosis.

## Increment1.73 — field-aware invert of a prior RemoveOpacityKeyframe command

Field-aware invert now has an official persist path for a prior non-tip RemoveOpacityKeyframe of the only linear keyframe on the left remnant at local time 0 with value 0.5: only that command's keyframe write set is restored when those fields still match the command's after-image. Removing the last keyframe leaves the opacity effect with an empty keyframes list; invert restores the keyframe on that effect, keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip is whole-group UNDO_CONFLICT and does not roll the database back. A later SetOpacityKeyframe at the same local time after removal mints a new keyframe id, so fieldInvertConflicts stays false and invert then refuses DUPLICATE_KEYFRAME; that code is not retargeted and is not the official conflict path. Official later work is therefore a later marker or a text edit. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production edit algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert, SetClipOpacity invert, or auto-close of a vacated source gap. Invert still mints a new sequence version when clock-stripped transitions change, and now also when clock-stripped effects change; when a clip's closed effects change, invert also mints a new clip version and a new sequence version. This slice does not retarget IMMUTABLE_VERSION_CONFLICT. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, enters clip opacity 0.5 and local frame 0, sets a linear opacity keyframe, removes that keyframe at the same local frame, adds a later marker, inverts the RemoveOpacityKeyframe command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0080 and evidence/field-invert-remove-opacity-keyframe. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73 and 4c844a64 are preserved, no push or remote diagnosis.

## Increment1.74 — field-aware invert of a prior SetClipOpacity command

Field-aware invert now has an official persist path for a prior non-tip SetClipOpacity of the left remnant to static value 0.5, from a clip that had no opacity effect: only that command's opacity write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert removes the opacity effect from the left remnant, keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip, or a later SetClipOpacity rewrite to 0.25 that reuses the effect id, is whole-group UNDO_CONFLICT and does not roll the database back. Official later work is a later marker or a text edit, not a later SetOpacityKeyframe or RemoveOpacityKeyframe. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert or auto-close of a vacated source gap. The Increment 1.73 invert version bump stays: invert still mints a new sequence version when clock-stripped transitions or effects change, and still mints new clip and sequence versions when a clip's referenced effects are already in the bump set. This slice does not retarget IMMUTABLE_VERSION_CONFLICT and needed no further production change, because creating a static opacity effect already changes clip effectIds. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, enters clip opacity 0.5, applies persisted clip opacity, adds a later marker, inverts the SetClipOpacity command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe / RemoveOpacityKeyframe, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0081 and evidence/field-invert-set-clip-opacity. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64 and 223475fe are preserved, no push or remote diagnosis.

## Increment1.75 — field-aware invert of a prior SetClipTransform command

Field-aware invert now has an official persist path for a prior non-tip SetClipTransform of the left remnant to {...identityTransform2d, translateX: 16}, from a clip that had no transform effect: only that command's transform write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert removes the transform effect from the left remnant, keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip, or a later SetClipTransform rewrite to translateX 32 that reuses the effect id, is whole-group UNDO_CONFLICT and does not roll the database back. Official later work is a later marker or a text edit, not a later SetClipOpacity, SetOpacityKeyframe, RemoveOpacityKeyframe, SetClipCrop, or SetClipColorBasic. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert, SetClipCrop invert, SetClipColorBasic invert, or auto-close of a vacated source gap. The Increment 1.73 invert version bump stays: invert still mints a new sequence version when clock-stripped transitions or effects change, and still mints new clip and sequence versions when a clip's referenced effects are already in the bump set. This slice does not retarget IMMUTABLE_VERSION_CONFLICT and needed no further production change, because creating a static transform effect already changes clip effectIds. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, enters translate X 16 (defaults remain translate Y 0, uniform scale 1, and rotation 0), applies persisted transform, adds a later marker, inverts the SetClipTransform command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe / RemoveOpacityKeyframe / SetClipOpacity, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0082 and evidence/field-invert-set-clip-transform. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64, 223475fe and c8aca307 are preserved, no push or remote diagnosis.

## Increment1.76 — field-aware invert of a prior SetClipCrop command

Field-aware invert now has an official persist path for a prior non-tip SetClipCrop of the left remnant to {...identityCrop, left: 0.25}, from a clip that had no crop effect: only that command's crop write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert removes the crop effect from the left remnant, keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip, or a later SetClipCrop rewrite to left 0.5 that reuses the effect id, is whole-group UNDO_CONFLICT and does not roll the database back. Official later work is a later marker or a text edit, not a later SetClipTransform, SetClipOpacity, SetOpacityKeyframe, RemoveOpacityKeyframe, or SetClipColorBasic. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert, SetClipColorBasic invert, or auto-close of a vacated source gap. The Increment 1.73 invert version bump stays: invert still mints a new sequence version when clock-stripped transitions or effects change, and still mints new clip and sequence versions when a clip's referenced effects are already in the bump set. This slice does not retarget IMMUTABLE_VERSION_CONFLICT and needed no further production change, because creating a static crop effect already changes clip effectIds. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, enters crop left 0.25 (defaults remain top 0, right 1, and bottom 1), applies persisted crop, adds a later marker, inverts the SetClipCrop command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe / RemoveOpacityKeyframe / SetClipOpacity / SetClipTransform, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0083 and evidence/field-invert-set-clip-crop. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64, 223475fe, c8aca307 and 86407188 are preserved, no push or remote diagnosis.

## Increment1.77 — field-aware invert of a prior SetClipColorBasic command

Field-aware invert now has an official persist path for a prior non-tip SetClipColorBasic of the left remnant to {...identityColorBasic, exposureStops: 1}, from a clip that had no colorBasic effect: only that command's colorBasic write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert removes the colorBasic effect from the left remnant, keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip, or a later SetClipColorBasic rewrite to exposureStops 2 that reuses the effect id, is whole-group UNDO_CONFLICT and does not roll the database back. Official later work is a later marker or a text edit, not a later SetClipCrop, SetClipTransform, SetClipOpacity, SetOpacityKeyframe, or RemoveOpacityKeyframe. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert, SetMasterAudio invert, or auto-close of a vacated source gap. The Increment 1.73 invert version bump stays: invert still mints a new sequence version when clock-stripped transitions or effects change, and still mints new clip and sequence versions when a clip's referenced effects are already in the bump set. This slice does not retarget IMMUTABLE_VERSION_CONFLICT and needed no further production change, because creating a static colorBasic effect already changes clip effectIds. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, enters exposure stops 1 (defaults remain contrast 1 and saturation 1), applies persisted colorBasic, adds a later marker, inverts the SetClipColorBasic command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe / RemoveOpacityKeyframe / SetClipOpacity / SetClipTransform / SetClipCrop, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0084 and evidence/field-invert-set-clip-color-basic. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64, 223475fe, c8aca307, 86407188 and 34377075 are preserved, no push or remote diagnosis.

## Increment1.78 — field-aware invert of a prior SetMasterAudio command

Field-aware invert now has an official persist path for a prior non-tip SetMasterAudio(gainDb: -6): only that command's master-audio write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores default master gain 0 (pan 0, muted false, solo false), keeps both remnants' starts and the sequence duration, keeps the followed stay cue and the unmoved hello cue, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip, or a later SetMasterAudio rewrite to gainDb -12 that is a real write-set conflict, is whole-group UNDO_CONFLICT and does not roll the database back. Official later work is a later marker or a text edit, not a later SetClipColorBasic, SetClipCrop, SetClipTransform, SetClipOpacity, SetOpacityKeyframe, or RemoveOpacityKeyframe. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not officialize mid-clip insert paste invert, ripple-close or ripple-trim-lengthen invert, or auto-close of a vacated source gap. The Increment 1.73 invert version bump stays, and is extended in the same bounded way: invert still mints a new sequence version when clock-stripped transitions or effects change, still mints new clip and sequence versions when a clip's referenced effects are already in the bump set, and now also mints a new sequence version when clock-stripped audioBuses change, because sequence fingerprints already close the resolved audio bus. Persist-path invert after later markers first refused IMMUTABLE_VERSION_CONFLICT; that code is not retargeted, and production edit algebra is unchanged. A workbench path splits at 1s, adds hello and stay cues, enters master gain -6 dB on the existing master-gain-db control, saves persisted master audio, adds a later marker, inverts the SetMasterAudio command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe / RemoveOpacityKeyframe / SetClipOpacity / SetClipTransform / SetClipCrop / SetClipColorBasic, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0085 and evidence/field-invert-set-master-audio. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64, 223475fe, c8aca307, 86407188, 34377075 and 4ac74b11 are preserved, no push or remote diagnosis.

## Increment1.79 — field-aware invert of a prior ripple-close command

Field-aware invert now has an official persist path for a prior non-tip range ripple-close of a vacated leave-gap hole: after a 1s split, hello/stay cues, and a leave-gap MoveClip of the right remnant by +1s, RippleDeleteClips([], range: TimeRange(1s, 1s)) closes [1, 2). Only that close command's write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert reopens the hole, moves later content back, keeps the left remnant and the unmoved hello cue at 0, returns the right remnant to 2, follows stay back to 2.5, restores sequence duration 4, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip, or a later leave-gap move of the packed right remnant that is a real write-set conflict, is whole-group UNDO_CONFLICT and does not roll the database back. Official later work is a later marker or a text edit, not a later SetMasterAudio, SetClipColorBasic, leave-gap trim of a remaining remnant, or a later move as success. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, IMPLICIT_GAP, RIPPLE_RANGE_AND_SELECTION, or RIPPLE_RANGE_NOT_CONTIGUOUS, and does not officialize mid-clip insert paste invert, invert of a non-trailing leave-gap delete / LiftClips, ripple-trim-lengthen invert, or auto-close of a vacated source gap as a MoveClips mode. The Increment 1.73 and 1.78 invert version bumps stay. Persist-path invert after later markers needed no further version bump. A bounded invert-path change in field_invert.dart restores in-place fields first, then inserts a missing track gap by timeline start rather than appending it; media clips still append, so invert of a non-trailing leave-gap delete, LiftClips, or mid-span insert paste still refuses IMPLICIT_GAP. A workbench path splits at 1s, adds hello and stay cues, selects the right remnant, leave-gap moves it by 30 frames on the existing single-clip Move button, enters ripple-close start 1s and duration 1s, applies Ripple close range, adds a later marker, inverts the rippleDeleteClips command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is used only to leave the admitted source hole. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe / RemoveOpacityKeyframe / SetClipOpacity / SetClipTransform / SetClipCrop / SetClipColorBasic / SetMasterAudio, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0086 and evidence/field-invert-ripple-close. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64, 223475fe, c8aca307, 86407188, 34377075, 4ac74b11 and d66459ef are preserved, no push or remote diagnosis.

## Increment1.80 — field-aware invert of a prior ripple-trim-lengthen command

Field-aware invert now has an official persist path for a prior non-tip RippleTrimClip lengthen (positive Δ): after a 1s split and hello/stay cues, RippleTrimClip of the left remnant out by +1s grows left duration to 2 and shifts the right remnant and the followed stay cue. Only that lengthen command's write set is restored when those fields still match the command's after-image. A later unrelated SetMarkers does not conflict, so invert restores left duration 1, moves later content back (right start returns to 1, stay follows back to 1.5), keeps the unmoved hello at 0, restores sequence duration 3, and keeps the later markers. A later text edit of the followed stay cue, or of the unmoved hello cue, also does not conflict; invert keeps the new text. Invert of the tip, or a later second out-lengthen of the same left remnant that is a real write-set conflict, is whole-group UNDO_CONFLICT and does not roll the database back. Official later work is a later marker or a text edit, not a later SetMasterAudio, SetClipColorBasic, leave-gap trim of a remaining remnant, a later ripple-close, or a later move as success. Linear undo/redo stay tip snapshot restores. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, IMPLICIT_GAP, SOURCE_OUT_OF_RANGE, or CLIP_TOO_SHORT, and does not officialize mid-clip insert paste invert, invert of a non-trailing leave-gap delete / LiftClips, or auto-close as a MoveClips mode. The Increment 1.73 and 1.78 invert version bumps and the Increment 1.79 invert-path gap insertion stay unchanged. Persist-path invert after later markers needed no further version bump and no production change. A workbench path splits at 1s, adds hello and stay cues, selects the left remnant, leaves edit-frames at 30, applies Ripple trim out lengthen, adds a later marker, inverts the rippleTrimClip command, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. The single-clip Move button stays MoveClip and is not used on this path. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Video and caption mute/solo stay refused at admission; audio muted/solo stay SetAudioTrackState; syncLock is not toggled. Already-delivered ripple delete, ripple trim shorten, ripple-close, leave-gap trim, leave-gap delete, move, lift/cut, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip shorten / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe / RemoveOpacityKeyframe / SetClipOpacity / SetClipTransform / SetClipCrop / SetClipColorBasic / SetMasterAudio / range ripple-close, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, a complete invert matrix, the table's 0.02s off-grid offset, and I-006 are not in this slice. See ADR0087 and evidence/field-invert-ripple-trim-lengthen. I-005 and I-010 stay partial. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64, 223475fe, c8aca307, 86407188, 34377075, 4ac74b11, d66459ef and d19ec5dd are preserved, no push or remote diagnosis.

## Increment1.81 — official persist path for caption-aware SlipClip

Caption-aware SlipClip now has an official persist path for the already-specified s3 slip command. The command remains SlipClip(clipId, sourceDelta); this slice does not add includeLinks. When a project has captions, applyEdit and persistent-audio dispatch now admit SlipClip instead of refusing CAPTION_SYNC_EDIT_NOT_IMPLEMENTED. After the existing source-window shift, applySourceCaptionAbsolutes reprojects source-anchored cues that remain covered; clipLocal cues do not move because timelineRange is unchanged; absolute cues stay at author time. Official path: after a 1s split of a 3s clip, hello is clipLocal on the left remnant and stay is clipLocal on the right remnant; SlipClip of the left remnant by +15 source frames (Q.of(1, 2) on the 30fps grid) moves the left source start to 1/2, leaves both timeline ranges and sequence duration 3 unchanged, keeps TimeMap shape unchanged, leaves hello at 0 and stay at 3/2, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. Official conflict / refusal is whole-group: slipping the right remnant, which already uses source through the stream end, is SOURCE_OUT_OF_RANGE; uncovering a source-anchored cue is ANCHOR_OUT_OF_RANGE and does not silently convert to absolute or crop the source window; a locked sourceRange is FIELD_LOCKED. Those codes are not retargeted. Slip remains allowed if transition handles revalidate; a topology edit of a dissolve host remains TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL. A workbench Slip button consistent with existing trim/ripple buttons issues one persistent SlipClip from the existing edit-frames numeric path; tests go through the real button. The single-clip Move button stays MoveClip and must not silently become Slip. This slice does not invent pointer-drag Slip as a new gesture mode, and does not officialize field-aware invert of Slip, RollCut, SlideClip, mid-span insert-paste invert, auto-close as a MoveClips mode, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, MP4 burn-in, video/caption mute/solo, or syncLock. Official InversePatch kind stays restoreSnapshot. Linear undo/redo stay tip snapshot restores. The Increment 1.73 and 1.78 invert version bumps and the Increment 1.79 invert-path gap insertion stay unchanged. Production edit algebra of already-delivered commands, insertion order, and IMPLICIT_GAP are unchanged. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Already-delivered invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip / leave-gap MoveClip / LiftClips / reject-mode MoveClips / overwrite-mode MoveClips / insert-mode MoveClips / includeLinks=false MoveClips / overwrite-mode PasteClips / insert-mode PasteClips / SetDissolve / RemoveDissolve / SetOpacityKeyframe / RemoveOpacityKeyframe / SetClipOpacity / SetClipTransform / SetClipCrop / SetClipColorBasic / SetMasterAudio / range ripple-close / RippleTrimClip lengthen, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. See ADR 0088 and evidence/caption-slip-clip. I-005 and I-006 stay partial; this slice does not claim I-006 complete. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64, 223475fe, c8aca307, 86407188, 34377075, 4ac74b11, d66459ef, d19ec5dd and a7e7b040 are preserved, no push or remote diagnosis.

## Increment1.82 — official persist path for caption-aware RollCut

Caption-aware RollCut now has an official persist path for the already-specified s3 roll command. The command remains RollCut(leftId, rightId, delta); this slice does not add includeLinks. When a project has captions, applyEdit and persistent-audio dispatch now admit RollCut instead of refusing CAPTION_SYNC_EDIT_NOT_IMPLEMENTED. After the existing adjacent-cut geometry, applySourceCaptionAbsolutes reprojects source-anchored cues that remain covered, and followClipLocalCaptions moves clipLocal cues on the right; clipLocal cues on the left stay put because the left start is unchanged; absolute cues stay at author time. Official path: after a 1s split of a 3s clip, hello is clipLocal on the left remnant and stay is clipLocal on the right remnant; RollCut of the packed cut by +15 frames (Q.of(1, 2) on the 30fps grid) moves the cut from 1s to 1.5s, grows the left duration and later source to 1.5, starts the right at 1.5 with duration 1.5, leaves sequence duration 3 unchanged, leaves hello at 0, follows stay to 2, then undoes, redoes, archives a fork, and exports a VTT sidecar; preview and MP4 burn-in stay refused. Extract is not required. A third remnant, if present, stays put. Linked AV at the same cut, when used, rolls each member with its own source rate. Official conflict / refusal is whole-group: a later leave-gap move that breaks the cut is NOT_ADJACENT; a source-anchored cue that would straddle or leave the new windows is ANCHOR_OUT_OF_RANGE and does not silently convert to absolute or crop the source window; exhausting later source on the left then rolling further is SOURCE_OUT_OF_RANGE; a locked sourceRange is FIELD_LOCKED. Those codes, and CLIP_TOO_SHORT, are not retargeted. Current algebra already refuses RollCut when any transition exists; TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL is kept, and the official persist path is free of dissolves. A workbench Roll button consistent with existing trim/ripple/slip buttons issues one persistent RollCut of the selected clip and its adjacent neighbor from the existing edit-frames numeric path; tests go through the real button. The single-clip Move button stays MoveClip and must not silently become Roll or Slip. The Increment 1.81 Slip button stays SlipClip. This slice does not invent pointer-drag Roll as a new gesture mode, and does not officialize field-aware invert of Roll or Slip, SlideClip, mid-span insert-paste invert, auto-close as a MoveClips mode, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats in this checkout, MP4 burn-in, video/caption mute/solo, or syncLock. Official InversePatch kind stays restoreSnapshot. Linear undo/redo stay tip snapshot restores. The Increment 1.73 and 1.78 invert version bumps, the Increment 1.79 invert-path gap insertion, and the Increment 1.81 slip caption path stay unchanged. Production edit algebra of already-delivered commands, insertion order, and IMPLICIT_GAP are unchanged. Captions still do not enter the internal clipboard. An overwrite that would uncover or crop a source cue remains ANCHOR_OUT_OF_RANGE. An overwrite that would overlap a followed cue and a dest remnant remains CAPTION_OVERLAP. A later same-time keyframe after removal still refuses DUPLICATE_KEYFRAME. Already-delivered invert through Increment 1.80, caption-aware SlipClip, caption-aware grouping, insert-move leave-gap, overwrite, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. A diverging unlink invert remains LINK_OFFSET_MISMATCH. See ADR 0089 and evidence/caption-roll-cut. I-005 and I-006 stay partial; this slice does not claim I-006 complete. Ordinary local commit only; unpublished 54f62c06, 6f3e4a56, 59a32d36, deea2310, 30f92009, 95d34b33, e18b8a39, 0cb53944, b3597160, c4f58904, 55b474c4, 335c222f, 9ad68709, 1ed94974, 6a9b4baf, 97cc3e73, 4c844a64, 223475fe, c8aca307, 86407188, 34377075, 4ac74b11, d66459ef, d19ec5dd, a7e7b040 and a554fea are preserved, no push or remote diagnosis.

## Marker sidecar integration onto the feature branch (after Increment 1.82)

The already-verified official studio.markers.sidecar import/export (Increment M.1) and workbench path (Increment M.2) are integrated onto feat/studio-foundation-20261125 after Increment 1.82. This is not a new editing command and is not claimed as part of the original 104-spec snapshot. The format remains studio.markers.sidecar; it is not reinvented. Workbench import replaces all project markers via existing SetMarkers or refuses the whole file; unknown extra fields warn MARKER_SIDECAR_UNSUPPORTED and refuse; a clipLocal host that is missing or no longer covering remains ANCHOR_OUT_OF_RANGE and is not rewritten as absolute. Labels are not burned into preview or MP4. WebVTT chapters, CSV, and FCPXML stay closed. Increment 1.81 Slip and Increment 1.82 Roll production paths and workbench buttons stay intact. Official InversePatch kind stays restoreSnapshot. Production edit algebra of already-delivered commands, insertion order, IMPLICIT_GAP, the 1.73/1.78 invert version bumps, the 1.79 invert-path gap insertion, the 1.81 slip caption path, and the 1.82 roll caption path are unchanged. I-005 and I-006 stay partial; SlideClip is not opened. See ADR M.001, M.002, M.003 and evidence/marker-sidecar, evidence/marker-sidecar-workbench, and evidence/marker-sidecar-integration. Ordinary local commit only; unique parent 6732b081; no push and no merge to main.

## Increment C.1 — ASS sidecar export with an explicit font/layout policy

ASS sidecar export now has an official path when an explicit AssFontLayoutPolicy names the requested family, fallbacks, a registered available-family set, and PlayRes/layout values. encode without a policy remains ASS_EXPORT_FONT_POLICY_REQUIRED. A missing requested family is never written as the Style Fontname: the first registered fallback is written, warnings include ASS_FONT_SUBSTITUTED:requested->used and ASS_LAYOUT_MAY_CHANGE, and a Script Info comment records the same fact. No registered substitute is ASS_FONT_UNAVAILABLE. Available names are a DEV registry, not a claim that glyph files were embedded, shaped, or redistributed. Emoji, RTL, newlines, escaped literal braces/backslashes, and exact non-frame centisecond times roundtrip in this static ASS subset; collapsed sub-centisecond ranges are refused; unsupported styles and overrides still warn and are not executed. Import may use the same policy to list a Style-font substitute while still warning ASS_STYLE_FONT_NOT_RENDERED. A workbench path adds an emoji/RTL/newline cue, refuses Export ASS without a policy, then exports with a missing requested font so the sidecar and caption-export-status list the substitute and layout change. An SDK persist path also imports a missing-font ASS with the same policy, confirms SetCaptions(automatic: true) is MANUAL_FIELD_LOCKED on a hand-edited cue, keeps CAPTION_OVERLAP as the determined overlap policy, and keeps MP4 export CAPTION_RENDER_POLICY_NOT_IMPLEMENTED. Source-interval crop stays closed. Already-delivered plain caption domain, split/trim/exact positive-rate map, manual ownership, overlap rejection, bounded SRT/VTT/static ASS import, SRT/VTT export, cue versions/undo/reopen/archive/fork, clipLocal default, explicit source anchors, caption-aware editor commands, and field-aware invert stay unchanged. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not claim deterministic font shaping or lossless arbitrary ASS effects. See ADR0073 and evidence/caption-ass-export. I-005 and I-010 stay partial. Ordinary local commit only; unpublished ancestors on this branch are preserved, no push or remote diagnosis. Original 104/87 acceptance dependencies and the SQLite 3.54.1 gate stay protected; 87 and XD10 remain separately counted.

## Increment C.2 — declared script coverage fallback for ASS sidecar fonts

ASS sidecar font fallback now has an official declared-script coverage tightening when AssFontLayoutPolicy.scriptCoverage is non-empty. A Latin-only requested family is not written as if it covered CJK, emoji, or RTL: the first listed registered fallback that declares complete coverage of the sidecar text's bounded script tags (Latn/Han/Hira/Kana/Hang/Arab/Hebr/Zsye, not a full UCD Script property) is written, with ASS_FONT_COVERAGE_SUBSTITUTED and ASS_LAYOUT_MAY_CHANGE. No covering fallback is ASS_FONT_COVERAGE_UNAVAILABLE rather than silently keeping the original family. An empty coverage map keeps this branch's Increment C.1 name-only fallback and invents no coverage warnings. encode without a policy remains ASS_EXPORT_FONT_POLICY_REQUIRED. Import with a coverage policy lists the same substitute and still warns ASS_STYLE_FONT_NOT_RENDERED. A workbench path adds a CJK/emoji/RTL cue, fills the declared coverage map, and exports ASS so the sidecar and caption-export-status list the coverage substitute and do not write the Latin-only requested font. An SDK persist path also imports an Arabic ASS whose Style names that Latin-only family, confirms SetCaptions(automatic: true) is MANUAL_FIELD_LOCKED on a hand-edited cue, keeps CAPTION_OVERLAP, and keeps MP4 export CAPTION_RENDER_POLICY_NOT_IMPLEMENTED. Source-interval crop stays closed. Already-delivered name fallback, SRT/VTT export, static ASS import, caption-aware editor commands, and field-aware invert stay unchanged. Official InversePatch kind stays restoreSnapshot. This slice does not change production algebra, insertion order, or IMPLICIT_GAP, and does not claim deterministic shaping or lossless arbitrary ASS effects. This captions-side increment is C.2 so it does not collide with mainline 1.66/1.67 invert increments; Increment C.1 evidence remains in evidence/caption-ass-export. See ADR C.2 and evidence/caption-font-coverage-fallback. I-005 and I-010 stay partial. Ordinary local commit only; unpublished ancestors on this branch are preserved, no rebase onto the shared checkout tip, no push or remote diagnosis. Original 104/87 acceptance dependencies and the SQLite 3.54.1 gate stay protected; 87 and XD10 remain separately counted.
