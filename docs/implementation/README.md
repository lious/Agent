# 可运行基础切片

**不是完整视频编辑器。** 目前可运行：两个共享 Flutter 宿主，创建空工程、编辑标题、
SQLite 事务提交、撤销最新命令、退出重开。已有代码、真实 SQLite/Flutter 测试和 Linux
构建/启动证据；V-001/I-001/I-002/I-003 整任务仍为部分完成。

原始规划：[工程文档](../studio/README.md) · [87项任务](../studio/tasks/work-items.md)

- [范围/偏差 ADR](../adr/0001-foundation-slice.md)
- [执行进度](task-status.json)
- [三轮实际自审记录](REVIEW.md)
- [开发机工具链](../../tools/spikes/toolchain/linux-dev.json)
- `evidence/` 是本分支真实运行记录，不是旧设计的 schema 模拟测试。

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

## 启动

```sh
cd apps/studio_demo  # 或 apps/image_demo
flutter run -d linux
```

默认 demo 数据在系统临时目录 `studio-foundation-demo/<appId>.sqlite`，
**不是生产用户数据目录，也不保证被系统保留**。可用环境变量
`STUDIO_DEMO_DATA_DIR=/自己的开发目录` 指定稳定目录。demo 只操作合成工程，
不导入用户素材，不访问网络。新建 projectId 固定为 demo-project。

## 重跑验收（从仓库根）

```sh
python3 -m unittest discover -s tools/tests -v
python3 tools/acceptance/run_task.py I-001 --profile linux-dev --report artifacts/acceptance/I-001.json
python3 tools/acceptance/run_task.py I-002 --profile linux-dev --report artifacts/acceptance/I-002.json
python3 tools/acceptance/run_task.py I-003 --profile linux-dev --report artifacts/acceptance/I-003.json
python3 tools/spikes/toolchain/run_probe.py --profile linux-dev --report artifacts/acceptance/V-001.json
```

runner 的退出码 0 仅指本次已实现范围检查通过，报告始终明确
`fullTaskComplete:false`；未知 task/profile 退出 2，命令失败退出 1。
V-001 在每个 App 上执行 3 次 clean→release build→Xvfb 首帧启动，同时 3 次
全新 C++20 shared-library build 与真实 Dart FFI 调用。探针不是 FFmpeg 媒体引擎。

也可分别运行：

```sh
dart test packages/studio_contracts/test packages/studio_document/test packages/studio_store/test packages/studio_sdk/test
(cd packages/studio_editor_ui && flutter test)
flutter analyze
dart format --output=none --set-exit-if-changed packages apps/studio_demo/lib apps/image_demo/lib packages/studio_document/tool/generate_empty_fixture.dart tools/spikes/toolchain/ffi_probe.dart
```

Widget 测试必须在所属 Flutter package 运行，才能正确打包官方 Material UI shader。
Flutter 3.50 已拆出官方 `material_ui`（本版本 1.11.1），不用弃用的 material.dart。
CI 配方见 `docs/implementation/foundation-ci.yml`（只读权限、无部署）。当前 GitHub CLI 的 OAuth 授权缺少 workflow scope，GitHub 拒绝了工作流文件上传；本分支只提交不执行的 CI 配方，没有安装或声称远端 CI 已通过。若以后启用，需要用户另行授权 workflow 并把配方安装到 .github/workflows/。

## 代码地图

| 包/目录 | 已实现 |
| --- | --- |
| studio_contracts | AppProfile、namespace、稳定错误码、ID |
| studio_document | BigInt 有理时间/帧/sample/区间；2.0 文档值、工厂、部分 validator、JCS hash |
| studio_store | SQLite 初始迁移；namespace 查询；fence/CAS/receipt/journal/outbox 原子写；最新命令撤销 |
| studio_harness | scoped SessionRef 与 ProposalPort 契约；没有可执行 Agent |
| studio_sdk | 单一装配入口，显式 expectedRevision；未装配的媒体/归档抽象端口 |
| studio_editor_ui | 两宿主复用的真实标题编辑 UI |
| apps/* | 只有 AppProfile、开发数据路径与 Linux runner |
| tools/spikes/toolchain | 独立 C++20 ABI、Int64 往返和 namespace handle 探针 |

生产功能未完成：导入、时间线剪辑、.studioproj 包保存/恢复、FFmpeg 渲染导出、
音视频设备/硬件加速、Agent 执行、端侧模型、云生成、支付、发布。
不得将工作 SQLite 关闭重开测试称为上述工程归档或媒体闭环已完成。
