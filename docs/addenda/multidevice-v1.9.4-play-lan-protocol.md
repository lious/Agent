# 多端协作玩法增量 v1.9.4：同进程局域网协议扩展

本切片继续设计页「Studio 跨端协作｜剧组创作与实景剧本杀」在阶段 A 与 v1.9.3 有限局域网协议之后的 **软件/协议** 验收。它仍只用同一 Linux/Web 运行时里的两个逻辑对等端（`LoopbackPlayLanFabric`），不打开 LAN 套接字，不宣称两台物理设备已通。

这不是阶段 B 物理双机 E2E，不是正向 RTC、STUN/TURN 或可写 peer RPC，也不把 XD-003 / XD-006 / XD-010 标成完成。不扩展 `packages/studio_store` 的 schema v10，核心工程库仍天花板 v9。`LoopbackPlayLanFabric.claimPhysicalE2e()` 仍返回 `PLAY_LAN_PHYSICAL_E2E_UNCLAIMED`。冻结的 Increment 2.14 `lan_protocol_test.dart` 未改写。

## 本切片官方化的协议条款

- `snapshotRequest` 的答复必须按 **请求方** 的 (person, device, grant) 做 `PlaySession.view` 过滤，不得使用主持端笔记本。公共屏快照 `hasTruth` 为假，即使主持端快照为真。
- `crew.confidential` 不得投递到仅有 `public` 范围的客户端；演员 `sides.<characterId>` 只投递到绑定该角色的设备。
- 成功投递的 `event` 可用 `eventAck`（`ackSeq` + `eventSender`）确认。
- 重复或过期 `seq` 忽略，不二次应用。未知发送端是 `PLAY_LAN_UNKNOWN_PEER`。
- 收到 `goodbye` 后，该对等端再发非 goodbye 消息是 `PLAY_LAN_PEER_GONE`。

本切片不改 `packages/studio_store`、`apps/studio_web` 或工程 schema。
