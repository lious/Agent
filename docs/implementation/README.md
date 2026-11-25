# 可运行本地视频开发切片

**不是完整视频编辑器，也未完成全部87项。** 已有真实双 Flutter 宿主与共享 Dart/C++：
素材导入 → 单轨 split/trim/slip 等 → SQLite 事务 → 含原件工程 ZIP 保存 → 关闭重开 →
安全 fork 恢复 → FFmpeg 软件 H264/MP4 导出。原件/数据库不上传，无模型或付费 API。

当前可运行范围严格限制为 silent CFR Rec709 limited 8bit、1×、相同偶数尺寸 ≤2048。
有音轨输入需明确 video-only 确认；未知色彩、VFR、旋转、alpha 等不伪装成可导出。
原 104 文档不变；全部87项逐项保留原验收：18 partial、56 planned、13 blocked（验证资源）。
**整任务完成数为0**；blocked 不等于实现完成，尚有大量可继续的纯 Dart 工作。

原始规划：[工程文档](../studio/README.md) · [87项任务](../studio/tasks/work-items.md)

- [基础 ADR](../adr/0001-foundation-slice.md) · [本地视频范围/偏差 ADR 0002](../adr/0002-local-video-vertical-slice.md)
- [执行进度](task-status.json)
- [三轮实际自审记录](REVIEW.md)
- [开发机工具链](../../tools/spikes/toolchain/linux-dev.json)
- `evidence/` 是本分支真实运行记录，不是旧设计的 schema 模拟测试。

## 本轮真实保存与恢复增量

自动保存现在登记本机 SQLite checkpoint（空闲2秒/最长30秒/50次durable提交），
**不**自动打包素材或写云端；后台/切工程/关闭会立即请求本地 checkpoint。
UI 的 durable/checkpoint/explicit/target 状态来自持久回执，重开不丢失；可显式
保存本机恢复点、查看归档阶段、在发布前取消，并明确重新选择原路径后验证中断发布。
保存中 SDK 可继续提交编辑，归档回执仍只对应捕获的 revision，不回退 head。

详见 [ADR0003](../adr/0003-managed-checkpoints-and-local-save-recovery.md)。
本轮总计74个 Dart/Flutter 测试（0跳过，含新增11个保存/失败/虚拟时钟和5个崩溃测试，每阶段内部10次进程SIGKILL）、6个工具测试、3个CTest；双宿主各3次clean/release构建启动通过。完整退出草稿处理、
损坏数据库隔离恢复/日志压缩、物理断电/磁盘满及非Linux provider资格仍未完成。
新证据 `evidence/save-checkpoints/`；旧 local-video 证据是历史基线，不冒充本轮计数。

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
未声称其他 Flutter/Dart 版本验证通过。当前 sqlite3 2.x 适配器动态链接系统 SQLite，
不是已打包验证的 iOS/Android/Windows 插件；这些平台需另接可信库和门禁。

## 构建真实 native adapter / 启动

在上述基础依赖外，当前开发机实际链接 FFmpeg 7.1.x（不是旧 FFmpegKit binary）：

```sh
sudo apt-get install libavformat-dev libavcodec-dev libavutil-dev libswscale-dev nlohmann-json3-dev ffmpeg
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
输入归档路径保存 → Restore as fork → 输入 MP4 输出路径导出。无视频预览/音频混音/字幕编辑。
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

当前证据见 evidence/local-video/；当前共有 58 个 Dart/Flutter 测试（包含1000 seeded
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

## 代码地图

| 包/目录 | 已实现 |
| --- | --- |
| studio_contracts | AppProfile、namespace、稳定错误码、ID |
| studio_document | BigInt 有理时间/帧/sample/区间；2.0 文档值、工厂、部分 validator、JCS hash |
| studio_store | SQLite v1→v2→v3；revision/CAS/fence/receipt/outbox/历史定义与blob pins；最新快照撤销；CAS原件；受限ZIP归档/fork；Linux原子发布 |
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
