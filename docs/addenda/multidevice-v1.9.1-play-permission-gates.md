# 多端协作玩法增量 v1.9.1：MVP A 权限门收口

本切片只收紧 v1.9 单机原型里已记录、但当时未作为失败项的权限稽口。不是阶段
B，不是正向 RTC / XD-010，不扩展工程库 schema，也不把玩法项标为完成。核心
store 在本功能分支仍天花板 v9；`rejectPlayActionAsEditProposal` 仍只是玩法包内
边界助手，`edit_proposals` / schema v10 不进入本树。

## 收紧内容

- `cancelTask` / `reassignTask` 仅导演或副导演可调用；取消与转派仍保留历史，不抹除领取记录。助手禁止。
- `markTechnicalQuality` 仅导演、副导演或执行者可调用，只是技术/连续性标记，不是创作采纳。编剧、剪辑、助手不能任意标记。
- `_canIssueOfficial` 不再宽于 addendum：导演 / 副导演可下达正式任务；编剧仅在已明确指定的场次内派工；剪辑与 lead 执行者不能因职务或 `lead` 标记就签发正式任务（空场次/部门列表不是通配）。普通参与者仍只能提需求。
- `PlayDevice.allows` 不再把 `mysteryTruth` 当成对其它 scope 的通配。人 / 角色 / 设备分开授权；GM 笔记本可见谜底，同账号公共屏仍强制观众模式；一台仅持有 `mysteryTruth` 的计算设备不能因此领取角色私密输入。无合适计算设备时，授权主机本地执行是独立回退，不是 `allows` 通配。
- 复盘视频导出除玩家外，也必须取得 GM 这个人的单独同意；不能因角色是 GM 而省略。无同意时仍可保留文本复盘。

本切片不实现新的部门派工 API，不改 `packages/studio_store`、`apps/studio_web` 或工程 schema。
