# 多端增量 v1.4 — Web持久身份、原Harness适配和精确源缩略图

2026-11-25 Asia/Shanghai。承接t82/t83/t84，不替换原104份规格，不增删原87项，
XD10仍独立。适用限制/证据详见[ADR0008](../adr/0008-web-rtc-identity-and-indexed-source-preview.md)。

新增实际实现：Web RTCCertificate持久句柄/独立全指纹校验/显式metadata同意，
标准DTLS/SCTP host-only手动信令transport；原Harness的IDB事务适配、回执/outbox/
租约fence/心跳/结果hash/撤销/资源保留，和可点击的本机任务、回执读取/重开。
**Web正向加密会话未验证通过**：当前受管Chrome实际ICE候选为0，预检关闭并清晰报错；
不得把此fail-closed测试当作跨浏览器/跨native/物理设备成功。没有云端或中继回退。

原I-021落地：真正容器索引seek→解码前滚→按源PTS取帧，独立逐帧参考/20点精确时间
对照、低层VFR和非零PTS实测、独立取消generation、不可变有界LRU和UI源缩略图。
仍非完整播放、RenderGraph、代理生成/映射、音频设备时钟或AAC；编辑器VFR导入仍拒绝。

## 固定验收补充，不降低原任务标准

- XD-002：持久浏览器证书与race/reopen、独立pin/同意拒绝、IDB持久撤销本地回归已测；
  真实网络撤销/轮换/非Chrome平台待验。
- XD-003：真实浏览器ICE为0的拒绝已测；正向DTLS/SCTP交换明确blocked，不是complete。
- XD-005/006/007：原Harness对象、真实IDB原子回执、实际到期/重试/fence/资源冲突/
  心跳回退/结果hash失败/rollback/撤销和只读重开已测；不是transport/mock替代验收。
- I-021：源缩略图20点精确timestamp和像素对照、VFR/nonzero、缓存字节及entry上界、
  queued旧epoch/close/project drift无回流已测；代理映射、全P0平台与真实负载门禁未闭合。
- XD-010：需要两台真实设备；同一物理Linux的多进程/Chrome不能替代。

Web最小权限：用户主动展开面板并加载身份；没有自动监听/云信令/素材上传。
需要安全context（本地开发localhost例外）；生产HTTPS托管、LNA权限和各平台资格
未部署也未冒称通过。没有未认证peer HTTP endpoint。浏览器清理存储可丢身份/工程；
私钥不fallback明文，不自动恢复历史coordinator权限。Web权限不是移动后台运行许可。
