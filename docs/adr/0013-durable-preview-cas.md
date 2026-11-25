# ADR0013 — registered RGBA128 SchemaProxy / PTS-map CAS closure (increment1.9)

状态：受限Linux CFR/SDR开发实现；不改原104、87项验收/硬依赖，不宣称完整I-002/I-021。

## 决策 / 格式

不向闭合根新增字段。实际使用原Schema的Asset.proxyRefs全部必需字段，Blob.role=proxy/ptsMap，
路径分别为proxies/<SHA256>.rgba和proxies/<SHA256>.pts.json；这不是把旧临时目录路径塞进Schema。
RGBA8888图像序列是一个明确注册的派生格式，不冒称H264/任意平台视频代理。pipelineHash绑定
RGBA128/原PTS/版本1 sidecar/Rec709 SDR preview策略；改变字节/映射策略必须换pipelineHash。

sidecar封闭协议studio.preview-pts v1，绑定original source hash、pipelineHash、RGBA hash、
原生facts及逐帧SHA256。原始PTS/start/timeBase保留，不伪归一化。当前持久格式只开放已准入
CFR、单视频stream；精确验证每点(i/fps)、duration、原origin/timeBase、帧数/源duration、尺寸、
字节数、全blob与逐帧digest。VFR低层20点资格保留，但不擅开VFR编辑或持久代理准入。
未知pipeline/role、缺资源、错版本/PTS/size/hash、重叠/overflow、路径不规范/递归资源别名均拒绝。
纯document层仅做结构/业务metadata admission；它不是文件已存在/已经验hash的凭证。
实际SDK复用和归档读取分别执行字节、源/映射闭包验证。

## 发布 / 并发 / 数据所有权

所有生成、CAS发布、SQLite revision/writer CAS与pin事务在既有namespace maintenance lease内。
AttachPreviewProxies是受控SDK命令；常规SDK.edit拒绝外部直接投递，与受控import相同边界。
完整原件不变。Asset取得新不可变version，引用它的音/视频clip及sequence同时版本化，不复用
旧version替换内容。失败/取消或编辑漂移不更新项目；已发布未pin CAS会由显式GC回收。

SQLite原blob_edges保留所有历史revision的原件、RGBA与PTS-map；undo/归档/fork/关闭重开均不
丢资源。当前策略保守保留历史，不声称已完成历史裁剪/总namespace磁盘配额。每个live root派生
RGBA总量<=64MiB，单生成staging<=64MiB/2048帧、map<=1MiB、retained pixel LRU2MiB；
这些**不是整个CAS、所有历史或进程RSS上限**。磁盘满等I/O失败仍中止，不删除原件补空间。

FrameProxy对CAS文件仅持有非owning reader，dispose只释放缓存，不递归删除CAS目录。切项目、
取消与异步read由原playback generation/revision/epoch fence拒绝旧结果。源事实首次加载与实际
native probe核对，不逐帧重parse整Schema；冻结的blob metadata参与cache key，坏declared size
不能借已缓存reader绕过验证。先限长后hash读，避免恶意大map/raw先分配。

## 哈希不等于可信来源

归档checksum/逐帧hash仅证明自洽，不证明RGBA由声称的原件生成。SDK生成时登记本机trusted
producer cache record（.preview-proof-v1-<digest>.json），仅存原件/RGBA/map/pipeline hashes；
不是签名、密钥库或针对OS owner的防篡改机制。信任边界是与本地SQLite一样的受信host文件系统。
这些记录不打包、不通过peer传入；archive/peer的CAS写入口只接受规范SHA256文件名，不能写此
保留名字。没有本机记录时，首次接纳外来归档会在受限stage里真实native重新生成一次，核对
整个RGBA digest与原始facts后才登记；失败不创建/选择新项目。以后本机fork/reopen直接复用。

这一步额外解码只做一次foreign-producer qualification，不是每次seek全片解码。当前严格按
已注册byte recipe比对；其他CPU/平台字节策略未验，不能保证任意端代理直接复用。无可信路径
时明确失败，不偷偷忽略错误、信任自报来源或上传云端。不替代完整GPU/颜色golden资格。

## Crash / GC

复用同一稳定namespace lock；不删lock文件。只在持有该lease时回收规范UUIDv7的.proxy-v1-*.rgba、
.import-*、.restore-*文件，拒绝symlink/FIFO，不递归、不跟随链接、不碰未知/未来版本名字。
OS进程SIGKILL释放锁后，下次显式build/reuse或Collect local garbage回收遗留；**不是已实现
后台启动服务或启动UI自动扫描**。canonical CAS及producer record由同一SQLite pin-snapshot GC
决定，原件/历史pins不受影响；record不是可替代pin的存活证明。

## 用户操作 / 明确未完成

原Build timeline video preview proxies现在发布事务化持久资源；成功增加revision。再次点击、
有效归档恢复/fork/重开是reuse，不新增revision、不重新生成已在本机验证的代理。现有Play的
lazy load也可加载持久资源。Clear仅释放reader/cache，不删除已入历史的项目资源。
预览/导出仍是同一源时间graph；导出读取原件，绝不编码低清代理。best-effort保持旧图/跳帧、
非物理AV/非稳定帧率的限制不变。

rich Schema只读UI、全部资源类型/retainedSources/history裁剪、损坏代理的显式丢弃/重建UX、
全局CAS配额、持久VFR/多pipeline、原I-015/V-004/P0和其他平台仍未完成；不标整项complete。
完整实际命令、失败与最终结果见implementation/evidence/durable-proxy/。
