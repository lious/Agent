# ADR-0001 · 首批可运行基础切片，不把部分验收写成整任务完成

日期：2026-11-25（Asia/Shanghai）
状态：本功能分支采用；不改写原始工程规格。

## 依据与保持不变的架构

依据 `docs/studio/tasks/work-items.md` 的 V-001、I-001、I-002、I-003，
以及规格 1、2、5、5A、9。维持 Flutter UI / 纯 Dart 文档、Harness 与 SDK /
SQLite 事务存储 / 后续 C++20 FFmpeg 与各端硬件适配。Python 只运行验收与构建；
没有 Python 生产领域实现。未实现另一个视频栈。

## 本次完成的纵切

两个 Linux Flutter 宿主注入不同 AppProfile，实际创建空 ProjectDocument 2.0.0，
修改标题、SQLite 原子提交、receipt 幂等、撤销最新命令产生新 revision、关闭重开。
领域有有理时间、帧/sample 换算、半开区间、闭合结构检查和部分语义检查。

全部四项**整任务仍为 partial**，不是 done。范围分段不是放宽原任务验收。
原始 87 项清单和导出校验和保持历史快照不变，实时进度另见
`docs/implementation/task-status.json`。

## 明确范围收缩和未实现合同

- **V-001**：只有当前 Linux x64 云端开发机的干净构建、首帧启动和独立
  Dart↔C++20 C ABI 探针。没有冻结正式 P0 手机/Mac，没有验证 FFmpeg、纹理、硬件音频。
  其他平台没有靠目录占位宣称成功。
- **I-001**：两个最小可运行宿主，不是两个完整编辑器。AppProfile 首先落实
  appId / region / features / version 和 namespace；tenantPolicy、品牌资产、
  modelCatalog 与 exportPreset 装配待后续能力。SDK 只暴露已有功能；未来媒体导入、
  本地渲染、工程归档恢复是**无实现的抽象 Port**，未安装也未调用。
- **I-002**：完整 Project 2.0.0 JSON Schema 从 `spec/s5.md` 复制并嵌入 Dart，
  测试比较三者相等。结构检查器只实现这份 schema 使用的封闭 vocabulary，
  **不是通用 JSON Schema 2020-12 引擎或完整 Schema conformance 声明**。
  已有时间、基础 ID、空工程外键、轨道区间、bus 输出环等检查；其余全部外键、
  TimeMap/转场 handles、冻结源、故事板/多模态/Harness Schema 及版本迁移未完成。
  没有外部 JSON/ZIP 导入入口：严格重复键读取器、UTF8 归档读取、安全路径检查未交付。
  JCS 用 `json_canonicalizer`，依赖锁定在 pubspec.lock；不自行用 double 存 I64。
- **安全写入边界**：Repository 只接受工厂生成的空工程（可变标题、revision）。
  其他结构即使通过当前 validator，也返回 FEATURE_NOT_IMPLEMENTED，不借不完整
  语义校验静默重写用户工程。未知 extensions 在 Document 值中保留，写入此切片时拒绝。
  这是实现缺失的保护，不是许可门禁。
- **I-003**：只实现创建、重命名和撤销最新命令。没有任意实体 patch、完整 undo/redo
  栈、多资源 blob pins、定义闭包 revision planner、归档保存恢复、崩溃自动恢复 UI。
  标题变更不增加 Sequence.version；初始 Sequence 定义登记 entity_versions。
  writer fence 由可信宿主显式 CAS 接管；没有到期租约、后台续租和调度器。
- **数据库**：本版本独占 foundation workspace DB schema，初始迁移 user_version=1，
  checksum 核验、事务失败回滚。不得套到现有第三方数据库；合入更多模块前需按规格
  引入模块级迁移命名空间。DB 中 fixture blob 仅测试小字节，**不是生产媒体 CAS**。
- **隔离**：所有 Repository API 绑定三段 namespace，WriterToken 也绑定 namespace；
  两 App 可以访问相同内容 hash，但不能经 API 读对方 session/project/blob。
  同一文件逻辑隔离不等于操作系统沙箱，也不能防同进程恶意代码直接读数据库。
- **outbox**：仅与 commit 原子记录 `projection.documentChanged` 的待投影意图。
  没有远端 dispatcher，不会产生网络、模型、支付或上传副作用。

## 不变安全规则

没有付费 API、模型下载、用户素材、部署或用户 Mac 访问；没有远端自动合并。
许可未知默认 allow_with_warning 的项目规则未改动，也未把它扩展为隐私/预算/权限放行。
当前没有模型执行路径，因此不声称已实现模型许可评估器。

## 后续依赖

先扩展 I-002 完整语义/严格读取与 I-003 定义闭包，再接 I-004 媒体 CAS、导入探针、
确定性编辑算法、工程包保存/恢复、实际 FFmpeg 本地导出。取得 P0 设备后完成 V-001
平台门禁，不能以当前 Linux smoke 代替手机、macOS 或商店验证。
