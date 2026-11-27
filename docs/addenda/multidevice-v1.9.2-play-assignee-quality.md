# 多端协作玩法增量 v1.9.2：技术质量标记的领取人边界

本切片只收口 v1.9.1 留下的残余缺口：`markTechnicalQuality` 曾按执行者工种放行，并不校验是否为该任务的领取人。同时补一条 2.07 已实现但当时没有单独官方用例的签发负例：编剧空 `sceneIds` 不是通配。不是阶段 B，不是正向 RTC / XD-010，不扩展工程库 schema，也不把玩法项标为完成。核心 store 在本功能分支仍天花板 v9。

## 收紧内容

- `markTechnicalQuality` 只允许导演、副导演，或该任务的领取人（`claimedByPersonId`）。仅有执行者工种但不是该任务领取人的人被拒绝。成功标记后不产生创作采纳，`adoptions` 仍为空，任务仍为 submitted。
- 编剧 `sceneIds` 为空时，不能签发未指派场次的官方任务。本条只补官方测试，不改 2.07 的 `_canIssueOfficial` 逻辑。
- 不改 2.07 已收口的取消/转派、谜底非通配、复盘视频需 GM 本人同意等行为。

本切片不改 `packages/studio_store`、`apps/studio_web` 或工程 schema。
