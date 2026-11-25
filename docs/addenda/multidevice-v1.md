# 多端 + 同一会话分布式计算增量 v1.2.0

有效需求：t83u「web、桌面、iOS、安卓…多设备直通互联协同工作」；t84u进一步明确
「同一个会话…多端调度算力分配任务协同」。本增量是用户新增范围，不改写原104份导出，
不把原87项改成“已完成”，也不只交付文件同步/工程fork。

## v1.2.0 实现增量

新增Linux真实OS加密安全存储身份与显式App配对面板；原始Harness PlanGraph下同会话
一远端/一本地免费元数据CPU任务、权限回执/撤销/重新配对；SQLite v6受限素材inbox，
逐块hash/持久断点/最终hash/原子ready回执。真实libsecret+Flutter原生UI+TLS+SQLite
已运行，不是模拟transport。具体限额、用户路径与安全边界见ADR0006及
`evidence/peer-ui-blob/`。原104快照不改，原87与新增XD10独立追踪。

**仅Linux同机协议/App集成通过，不冒充物理多设备、Web加密transport或其他平台资格。**
OS identity初始生成固定选定IP，无轮换UI；一session一peer；inbox不是完整项目CAS。
Web仍是真实可编辑宿主，但没有弱化身份门禁来假装已接入native mTLS。

## v1.1.0 实现增量

在v1.0.0纯核心/持久lease基线上，新增native成熟TLS双向认证直连、HTTP前校验精确证书指纹、SQLite一次性离线配对确认/限定plan-node grant/epoch撤销/持久请求幂等、真实同会话双子进程HTTPS计算、每设备单重任务、保守资源隔离与LOCAL-owner boot CAS接管/不重置预算/硬attempt deadline。实际API与安全界限见 ADR0005 和 evidence/peer-tls-sqlite；原104快照不改。**不是物理多设备通过，也未完成Web transport、OS密钥库或App配对UI。** 没有生产/公网服务或付费中继。

以下v1.1.0和“v1.0.0基线”段落保留历史交付边界（其中“配对/网络未实现”仅指旧版），当前进度以版本增量、ADR和独立XD任务状态为准。

## 既有合同与增量

沿用原9节 Session/Branch/Run 与 Project/Revision 分离、10节
DurableScheduler.tick(monotonic,bootEpoch)、10I `urn:studio:harness-runtime:1.0.0`
PlanGraph/Node/Pin/U63、10D intent/receipt/outbox/唯一终态。Session scope必须与namespace
一致；Project正式编辑仍单writer/fence/CAS，计算结果只生成候选，不直接改变revision。

新增 `urn:studio:device-session:1.0.0` 的 TaskLease 编码版本：coordinatorBoot、sessionId、
nodeId、deviceId、planHash、inputHash、fence/cancelEpoch/untilMs（U63十进制字符串）。
U63不能经JS Number；fence在Dart里为BigInt。时钟只解释为coordinator boot内的单调时间，
不是对端壁钟；租约到期拒绝旧worker结果，即使工作事实上已结束。未来网络消息外层必须
携带协议版本、消息ID、鉴权设备身份、scope、会话/plan pin和重放防护，不能把这个值对象
当凭据。

### v1.0.0实际代码基线（历史；当前增量见上）

* `studio_document`/`studio_harness` 运行核心无 dart:io/FFI；shared caption/DSP/PlanGraph/
  device placement/lease codec真实在Chrome执行。新增 `apps/studio_web` 为可编辑Flutter Web
  宿主：标题/字幕提交、SRT导入、VTT输出、JSON下载；不是只读展示端。
* BrowserProjectStore使用实际IndexedDB readwrite事务执行revision CAS、命令幂等、高水位
  entity versions，`transaction.complete`才ACK；strict durability只是浏览器提示，不能
  伪装成POSIX fsync或SQLite资格。浏览器可能逐出/清理数据，UI明确要求导出；目前只支持
  元数据/普通字幕，未支持视频处理/完整资源工程包。
* 这是显式平台适配偏差：native仍共享Dart+SQLite+C++FFmpeg主架构；Web不能import native
  StudioWorkspace/FFI，所以独立宿主只依赖纯核心和browser storage。Web SQLite WASM/OPFS
  与完整媒体适配尚未实现，不把IndexedDB算I-003在Web通过。后续统一Coordinator接口，
  不能用stub媒体/SQLite假装全端功能相同。
* 原PlanGraph wire的受限执行子集：tool/qa/reduce/checkpoint、allSuccess、always guard、
  localCpu/localGpu、none/localCandidate、maxCostMicros=0。付费/模型/正式projectProposal
  等不支持情况直接拒绝，不改为“免费/已审批”。完整原合同仍保留未实现状态。
* 同Session按受信host登记的已验证runtime/capability/model inventory、可用内存、负载、
  权限epoch、会话scope、前台和撤销状态做确定性placement。不接受未经配对的网络自报
  当资格证书。当前VerifiedDevice只是host registry值对象，**配对/签名/实时撤销传播未实现**。
* SQLite v4实际持久化Plan/step attempt/lease/progress/唯一终态hash与candidate outbox，
  依赖未完成不领取，expiry重试递增fence，取消后迟到结果拒绝，重复完成只接受同结果，
  工程revision不变。重开DB可读取同boot状态。旧coordinator boot不能自行接管/重置预算；
  新boot恢复/权威接管还需显式协议，当前fail-closed，不谎称完整重启恢复。
* 两个真实Linux子进程在同一持久Session执行固定免费SHA256/RMS CPU任务，校验输入/输出
  hash，结果原子入候选outbox。这是**单机多进程执行/协议集成**，不是跨物理设备、加密网络、
  浏览器到native网络互联或多机算力验收。无任意shell/模型远程执行器。

## 必须补齐的安全/网络/资源合同

以下为完整目标合同，当前子范围仅以v1.2.0/ADR0006证据为准；其中“尚未实现”历史描述不代表全部现状。

1. **显式可信配对**：本机生成设备密钥；一次性有过期时间的人工确认/QR offer绑定身份
   指纹、scope、能力和允许传输的资源；密钥由系统安全存储持有，不入项目/日志/会话归档。
   scoped grant可撤销并递增epoch；领取、心跳、结果、资源分块每次都重验。默认启动没有peer endpoint；只有显式配对后才有scope受限mTLS端点，绝不能把trusted-local SQLite API直接映射成peer API。
2. **加密与可达性**：优先用户控制的局域网直连（受信TLS或等价经审查实现）；Web transport
   需实际浏览器支持的协议/受信证书或WebRTC DataChannel适配。此版本不预设必须WebRTC、
   不承诺任意NAT可直连。信令/发现只交换最小连接元数据；素材数据另授权。没有用户启用
   不使用公共信令/云素材备份/付费TURN。不可达返回DIRECT_UNREACHABLE，不能静默回退。
3. **素材/结果传输**：scope内BlobRef白名单、总大小/块大小/总配额、逐块hash和最终hash、
   持久接收位图/幂等块ID、断点续传、隔离stage、校验后原子认领CAS。绝不接受对端任意
   文件路径，不上传整个素材库。当前受限inbox传输不等于完整项目CAS互传。
4. **同会话调度**：local重任务默认每设备一个、资源/温度/前后台变化停止新领取；浏览器
   关闭/挂起不能保证心跳。不会把“任意一个模型”切分显存；只调度独立任务/显式可分子任务。
   模型缺失时拒绝/换合适已授权设备，不自动下载大权重、云调用或扩大上传同意。
5. **故障/计费/结果**：至少一次消息+持久幂等，不假设网络exactly-once。intent/receipt分离；
   付费unknown只查对账，不重复提交；reserve/settle/release与唯一终态事务绑定。当前执行器
   拒绝付费节点，并未实现完整预算账本。lease/fence/cancel/device/privacy/rights epoch、
   plan pin、result schema/hash/provenance都须重验；不因重试恢复已撤销权限。
6. **共同编辑**：同一Session可并行算力/候选，不意味着多人同一Project无锁写。编辑接受走
   单writer lease+revision/readSet CAS，冲突显示/重提，不LWW覆盖，不擅自引入CRDT。

## 分端能力与验收层级

| 目标 | 本轮层级 | 仍未验证/未实现 |
|---|---|---|
| Linux desktop | 原生Flutter/SQLite/软件FFmpeg已有真实路径；新增字幕/调度协议测试 | 物理跨设备、完整媒体互传、完整87项 |
| Web / Linux Chrome | 真实可编辑Flutter Web、IndexedDB CAS与shared核心 | 完整媒体/模型/SQLiteWASM/后台、其他浏览器 |
| macOS / Windows | 共享纯Dart合同与明确适配边界 | 原生构建、签名、文件/FFmpeg/加密网络实测 |
| iOS / Android | 目标平台，按前后台与设备资格准入 | 平台SDK/实机/签名/硬编/模型/后台限制实测 |
| 多物理设备 | 尚未验收 | 至少两台物理设备，真实加密传输与断网恢复/撤销/迟到结果证据 |

分别验收允许，但单机多浏览器窗口、Chrome单测、同机子进程和mock transport均不算最终
多物理设备通过。新任务见 `docs/implementation/multidevice-status.json`，与原87独立计数。

## 资料依据（2026-11-25，Asia/Shanghai）

* 原spec s9/s10/s10d/s10i（不改快照）。
* https://developer.mozilla.org/en-US/docs/Web/API/IDBTransaction/durability
* https://www.w3.org/TR/IndexedDB/ （strict为hint，transaction生命周期/原子性）
* https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Connectivity
* https://w3c.github.io/webrtc-pc/ （ICE/STUN/TURN/信令，不保证直连）

以上资料不等于所有平台已完成资格测试。本轮没有生产部署、模型权重、付费API、中继、
用户素材上传、OAuth权限变更或Mac访问。
