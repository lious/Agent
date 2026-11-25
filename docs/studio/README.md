# AI创作 Studio 工程规划归档

导出时间：2026-11-25 09:08:16（北京时间 UTC+8）。

来源：[当前正式Page](https://cursor.com/canvas/store-fa1f1df3-2eb9-4e13-93c0-0c955b705747/8ed17845-a86d-410a-a1fe-093e1a4a7dbb)。设计核验基准：2026-11-24（北京时间）；本次为最新已发布Page的仓库归档，不是再次验证其外部证据。

- [完整可读规格](spec/FULL-SPEC.md)；spec目录同时提供按原章节ID拆分的文件。
- [完整任务卡片](tasks/work-items.md)、[CSV](tasks/work-items.csv)、[JSON](tasks/work-items.json)：26项技术验证 unvalidated；61项功能实现 planned。
- [依赖](tasks/dependency-edges.csv)、[覆盖](tasks/coverage.csv)、[里程碑](tasks/milestones.json)。
- [既有设计验证边界](tasks/VALIDATION.md)、[原始/兼容回归结果](tasks/regression-raw.json)。既有测试仅为设计合同与合成测试，不是App、模型、真机、性能或上线验证。
- [结构化完整Page数据](reference/page-data.json)：保全筛选/分页未全部显示的数据、完整任务合同和Schema等全部顶层数据；配合[Page源码备份](reference/page-source.canvas.tsx)可恢复原始呈现和Schema构造。源码备份是规划文档，不是可运行App。

## 最新执行规则（t80u，优先于历史快照）

用户已明确授权本项目后续代码在助手云端开发环境与 GitHub `lious/Agent` 仓库之间处理、提交和推送，无需向当前本地电脑通讯；不得读取、同步或改动用户 Mac 旧工程。本项目旧的 offline-only / 源码不得云端处理表述不再作为当前限制。历史Page快照原文保留，仅用于追溯；发生冲突时以本节最新授权为准。此授权不等于允许启动任意任务、对外发布、购买或访问其他仓库。

本次范围仅为文档入库，87项任务没有启动。

## 当前状态与约束

本次仅导出文档；未启动87项开发/验证任务，未连接用户Mac、读取现有工程源码、部署、购买或调用生成模型。个人开发者商业用途；许可信息缺失默认 allow_with_warning，许可事实不变且不代表已获授权。支付、隐私、上传、系统权限及真实服务拒绝不因此绕过。

引用链接为原规格的证据记录；不是本次重新核验。研究旧Page不是主规格。所有本机绝对审计路径替换为中性占位符，未打包附件、凭据或无关工作区。除路径脱敏外正式内容保全；分页/选择器完整数据另保留在page-data.json及完整任务文件。

完整性校验见 EXPORT-VALIDATION.md 与 SHA256SUMS。
