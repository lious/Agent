# ADR0027 — 复用持久命令journal的多级Undo/Redo，不新增历史真相表

状态：原I-005的有界可验收子集，仍partial；原s3/s5a验收/依赖及原104不改。沿用SQLite3.54.1、Schema9、commands/revisions/snapshots/receipts/events/outbox/blob_edges和writer-fence，**无新表/迁移/历史删除**。

## 权威状态与事务

原SDK只反转物理最新command，因此连续Undo会撤销上一次Undo而来回切换。新SDK/UI用持久journal重建逻辑cursor：普通已提交命令push undo、清redo；`undo@historyVersion1` pop原command并push本次undo ID；redo接受undoCommandId，恢复**该undo已保存的before-image**，不重跑原模型/转码/命令。再次undo仍指向原业务command。No-op只有receipt而无command，不清redo。撤销后新编辑只使旧redo不可应用，不删command/event/snapshot/pins；失败和重复receipt也不改cursor。

cursor每次由一条SQL取得同一SQLite读取快照的head+有序journal，检查连续revision、parent/expected revision、before/after hash链、inputHash及v1控制语义；不是内存栈或JSON配置文件。当前实现O(n) journal读取/折叠、O(n) ID内存，未加第二索引/重建缓存/后台压缩；不声称百万历史UI性能或全I-005实时资格。坏JSON/未知控制版本明确拒绝，不能吞条目继续undo。未来性能优化不得把缓存变为真相或静默截断历史。

执行undo/redo仍在原BEGIN IMMEDIATE事务内，先revision/writer-fence/idempotency，再确认请求是逻辑tip。只接受命令ID，不接受调用者任意before JSON。真实before/after快照须hash/namespace/project/revision匹配、通过当前可写语义；当前contentHash（仅除Project.revision）须等于目标after内容。恢复精确实体版本，重新分配单调Project.revision；沿原定义账本验证、pins、事件、receipt、outbox一起commit。失败后cursor由同一未变journal重新计算，无内存pop先行。所有历史版本与原件保持；原entity max(version)+1分配规则不变。

本批采用保守**完整content/tip串行逆操作**：不自动撤销非tip，不做协作/AI插队后的字段级rebase；有冲突UNDO_CONFLICT，不能整库覆盖。read/write视为完整root，这不是原完整changedEntities/readSet/field-aware逆操作资格。EditOperation/batch未加入可嵌套undo，仍只有顶层repository/SDK入口。gesture coalescing/多选/吸附/复制粘贴/编组等原I-005缺口不因本批消失。

## Legacy与归档

现有`undoLatest` API保留原合同，不改已存payload/raw hash或把旧记录改写成新cursor。旧`undoLatest`作为真实已提交的**历史恢复步骤**保留于逻辑undo路径，可以逐步回到其前态；不是假造旧语义redo栈。原来重复Undo切换过的历史因此仍可完整按实际状态顺序遍历。真实旧store+document生成的seq.version0歧义/root raw-hash记录，经新四undo/四redo/re-edit验证；新写版本必须大于历史max，不能把旧内容读取资格当任意复用权限。

关闭重开从SQLite重建cursor；源工程journal留原DB。保存/归档当前内容、导入fork后本地revision0和**空undo/redo**，不把归档旧journal当本地已执行Command，不携带可执行旧Undo；源DB历史仍在。effects/AudioClip/link/captions/proxy等完整快照恢复，不靠各功能手写逆函数，不清空未知资源来降级。未知历史语义或资源不符合当前准入时明确拒绝；本批不放宽字体/mask/LUT等执行资格。字幕仍须显式sidecar/受支持消费者；不为了MP4静默丢字幕。

## 真验证与已知限制

测试含真实UI多步undo/redo、SDK实际AV+AAC AudioClip/crop/color/caption/proxy逐根恢复、重开/归档fork/预览/编码前像素/MP4；1000个seeded已提交标题编辑完整undo/redo，对每态contentHash断言（不是全部NLE随机操作已合格）；两个独立SQLite连接真实同时undo一胜一revision conflict；writer takeover、no-op/branch/幂等和late SQL trigger回滚。三次真实SIGKILL：两个只在显式标记的临时源码mirror内、COMMIT前barrier，另一个未改生产代码COMMIT后kill，均用未改当前代码重开校验。源项目/用户DB从不参与清理。准确冻结结果见evidence/command-history/summary.json，未运行项单列。

Schema9不能阻止旧可执行writer共写；此限制不因新cursor消除。startup/resume underrun仍未证解，不能靠本批绿测关闭。Linux CPU/软件服务边界、非GPU/物理同步/其他平台/RTC政策限制均保持。e23a559/c8c12d8未发布提交保全，本批只普通本地commit，无push或无新证据远端诊断。
