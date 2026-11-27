# 多端协作玩法增量 v1.9.3：有限局域网协议（同进程逻辑对等端）

本切片为设计页「Studio 跨端协作｜剧组创作与实景剧本杀」在阶段 A 之后的
**有限局域网软件/协议**落地。它在 `packages/studio_play` 增加
`PlayLanEnvelope` / `PlayLanEndpoint` / `LoopbackPlayLanFabric`，用同一
Linux/Web 运行时里的两个逻辑对等端覆盖握手、心跳、序号、授权与范围过滤。

这不是阶段 B 物理双机 E2E，不是正向 RTC、STUN/TURN 或可写 peer RPC，也不把
XD-003 / XD-006 / XD-010 标成完成。不扩展 `packages/studio_store` 的 schema
v10，核心工程库仍天花板 v9。`LoopbackPlayLanFabric.claimPhysicalE2e()` 显式
返回 `PLAY_LAN_PHYSICAL_E2E_UNCLAIMED`。

## 收紧与新增内容

- 信封带 `sessionId`、单调 `seq`、发送端设备/人物、grant、scope 与 payload
  hash；篡改 hash 拒绝，会话不匹配拒绝。
- 接收端重新检查 grant：撤销后不能再投递。重复 seq 忽略，不二次应用。
- `mystery.truth` 不得投递到公共屏；快照经 `PlaySession.view` 过滤，公共屏
  `hasTruth` 为假。
- 传输只实现同进程环回织物，验证协议合同。不打开 LAN 套接字验收，不宣称两台
  物理设备已通。

本切片不改 `packages/studio_store`、`apps/studio_web` 或工程 schema。
