## 5C · 存盘协议：可恢复发布，不假装跨资源原子

```text
// save_coordinator.dart / package_writer.cpp / recovery_reconciler.dart
operation: queued -> capturing -> validating -> preparing -> writing -> verifying
 -> awaitingPublication -> publishing -> committed
前述任一阶段可 -> failed|cancelled；publishing后IO结果未知 -> publicationUncertain
publicationUncertain -> reconciling -> committed|failed（需核对实际目标）
// 不把unknown当成cancelled；committed不可原地回退，需另作保存/恢复操作。

1 capture: 在短读快照取(projectId,R,docHash,epochs)，固定闭包与pin。
  project_heads.snapshot_hash是该R完整文档hash，不保证“只有checkpoint时才有正文”。
  P1每个完成编辑事务先持久化canonical after文档/逆补丁CAS（仅工程元数据），
  再提交SQLite。已有相同hash复用；大媒体只引用。连续拖动只在gestureEnd提交一次。
2 intent: 保存操作/目标grant ID/旧目标版本/hash/旧良好副本引用/固定R/策略写入
  workspace操作journal并FULL提交。journal不含凭据，不是跨文件系统事务日志。
3 prepare: 旧目标若存在，先确认替换授权并保留独立、已校验良好版本；不得先删除旧包。
  选同卷staging，流式写immutable blobs、snapshot和资源清单；逐文件hash/size。
  本机目录树：文件flush+fsync，子目录自底向上sync；需要时Darwin F_FULLFSYNC。
4 metadata: 先在内存定稿manifest精确bytes；checksums列全部条目（含manifest/sidecar，
  不含checksums自身）。写snapshot/sidecar/manifest，再写checksums并关闭ZIP中央目录；
  flush文件、sync staging目录。不存在manifest<->checksums自哈希环。
5 verify: 从写入的bytes回读结构/schema/引用/清单/hash/路径并校验固定R；
  不是“构建器说成功”即成功。snapshot与manifest的R/ns/hash必须一致。
6 publish: 重新核验live privacy/rights、pin、writer fence和目标版本；拿目标发布锁。
  本机受测单文件：staging file fsync -> 原子file replace -> 父目录sync。
  非空目录包仅新名字完成发布，不执行“先删旧目录再rename”。
  provider: 本机完整staging -> 明确同意的目标新文件流式复制/close -> 尽可能readBack；
  不支持conditional atomic replace则不原位覆盖唯一好副本，要求新名字/新document URI。
7 receipt: 达到StoragePort实际承诺级别后，FULL事务写SaveReceipt+target指针+事件，
  operation=committed。再通知UI；最后释放临时pin（长期保留根已转交receipt/backup）。
8 recovery: publish成功而receipt未写时，按journal限定target token核对完整hash/version，
  与当前隐私屏障再检查；可确认者补记receipt；不能确认者显示“目标写入结果待核实”。
  不重新提交付费任务，不倒退project head，不从不可信包执行journal命令。
// SaveJournal阶段字段在SQLite save_operations持久；诊断导出只含脱敏ID/hash。
// 最新良好副本指针是已校验checkpoint/receipt的派生投影，不是另一份工程真相。
// 检查点与回执的latest指针CAS只前进，不让较旧异步完成覆盖更新结果。
```

| 故障/平台 | 错误、恢复与UI合同 |
| --- | --- |
| CAS→DB间隙 | CAS文件同步后DB提交前崩溃：孤儿文件可按操作日志认领或延迟GC；绝不把文件rename和SQLite称一个原子事务。DB成功且ACK丢失：按commandId+inputHash查询receipt，异hash拒绝；before/after/inverse pins均可验证。CAS未落盘不得让DB先引用ready。 |
| DISK_FULL / STORAGE_PERMISSION_REVOKED / DEVICE_REMOVED | 事务失败不显示已记录；留最后durable文档、草稿和错误，禁继续无界累积编辑。包写失败不动良好旧包；保留可重试固定R的journal与有效staging，提供释放未引用缓存/重新授权/选择新位置。不得自动删原素材、唯一备份或把同名文件覆盖成部分包。预留16MiB元数据应急空间仅设计建议，不保证可处理任意磁盘故障。 |
| IO_ERROR / PUBLICATION_UNCERTAIN | rename/replace后父目录flush或receipt失败，可能已经发布；显示“本机编辑已记录；工程文件结果待核实”，保留新旧校验副本和pin，对账后再ACK。取消晚到返回ALREADY_PUBLISHED或PUBLICATION_UNCERTAIN，不删除刚发布文件冒充取消。取消ZIP写入只清理本操作私有临时文件，外部不完整新文件也先列清理提示。 |
| 本机POSIX / Linux / Apple沙盒 | 只有StoragePort已证明支持的同卷单文件replace+file/directory sync才报告localDurable。fsync不能承诺坏控制器/物理介质永不丢。Apple文件协调使用NSFileCoordinator/UIDocument，security scoped grant仅本地存，不进工程；系统终止仍可能中断未ACK写。iCloud/文件provider即使URL像本地路径也不能套此保证。 |
| Windows | flush staging用FlushFileBuffers；ReplaceFileW仅同卷且按其失败码恢复原名/backup名，不能把任何失败都等同原文件完全未动。REPLACEFILE_WRITE_THROUGH官方标不支持，不能借该flag宣称落盘。共享句柄/ACL/杀软导致占用报TARGET_BUSY。替换后按适配器可证实的metadata保证回执；未认证文件系统/SMB按较弱provider级别，不一律localDurable。 |
| Android SAF / Apple document provider | SAF先查FLAG_SUPPORTS_WRITE/CREATE/RENAME等并持久化可持久权限；close不保证云端提交或其他设备可见。ACTION_CREATE_DOCUMENT同名会另加序号，不当作覆盖API。默认新建document URI，不把rw/wt行为当通用原子replace；不支持回读则providerAcceptedUnverified，并明确“已交给provider，未校验副本”。Apple协调不是远端云durability证明。 |
| Web | 运行数据库与CAS用选定浏览器支持的OPFS/IndexedDB事务，能力探测；外部下载/文件句柄是独立发布，不复用POSIX语义。未能获得持久存储授权/配额时显示“浏览器可能回收本机数据，请导出工程包”；用户取消文件选择不视为保存。Web具体浏览器崩溃/flush保证仍须按版本验收。 |
| PACKAGE_CORRUPT / MIGRATION_FAILED / WRITER_LOCKED | 先只读复制到隔离区检查；缓存坏可重建，原件坏报缺资源不替换为假图。完整快照坏才尝试受校验旧checkpoint并报告缺失revision范围。普通进程崩溃由SQLite恢复完整事务+CAS；DB真正损坏且无法证明旧head上界时默认建recovery fork，不用旧备份覆盖唯一原DB并复用revision号。迁移失败保旧包不变，锁冲突提供只读/另存副本，不强抢写者。 |

| 统一错误码 | 重试/补偿边界 |
| --- | --- |
| REVISION_CONFLICT / IDEMPOTENCY_CONFLICT / SAVE_PLAN_STALE | 不自动改expectedRevision或替换固定R；同key异语义拒绝。用户重算计划后用新请求；旧成功receipt原样返回。 |
| TARGET_VERSION_CONFLICT / TARGET_BUSY / WRITER_LOCKED / STALE_WRITER | 不盲目覆盖或抢锁；释放本worker私有lease，提示新位置/只读/重试。非协作外部写者无法由本App锁约束，目标无可信conditionalReplace时新名字保存。 |
| PRIVACY_EPOCH_CHANGED / RIGHTS_EPOCH_CHANGED / SNAPSHOT_PRIVACY_BARRIER | 停止新传输、废弃批准与当前plan；先重新计算删除/许可闭包，不能原payload自动重试。已经发出的字节/付费任务另列待处理，不假装可撤回。 |
| PENDING_MEDIA / RESOURCE_MISSING / PACKAGE_PROJECTION_MISMATCH | 前两者允许带清单保存不完整工程，禁止误标完整归档/最终render；投影与真实snapshot不一致必须重建失败，不用投影覆盖正文。 |
| UNSUPPORTED_ARCHIVE_VERSION / EXTENSION_REMAP_UNSUPPORTED / UNSAFE_ARCHIVE / ARCHIVE_LIMIT | 未来/未知对象只读或保留原包；危险路径直接隔离。调大体积上限需单次显式同意，不关闭路径/许可/哈希校验。 |
| CANCELLED_BEFORE_PUBLICATION / ALREADY_PUBLISHED / PUBLICATION_UNCERTAIN | 取消不是撤销。进入publicationUncertain后先对账；未确认的目标不能显示保存成功，也不能删除它假装未发布。 |

SQLite发布配置：运行库只放受控本机目录，禁止网络文件系统直接跑WAL；foreign_keys=ON、journal_mode=WAL、synchronous=FULL逐连接读取确认，不能把未知PRAGMA静默忽略当设置成功。Apple按VFS支持启用fullfsync；WAL checkpoint使用受控PASSIVE调度，不等同应用checkpoint。SQLite官方WAL文档指出WAL-reset修复在3.51.3及以后（或已列backport）；生产锁定经核验修复版本与源码hash，不无条件用手机系统SQLite。box测试解释器的SQLite版本只记录为测试环境，不构成该发布门禁通过。整库备份用SQLite Backup API/一致性快照，不能只复制活跃.db漏掉WAL；也不把多个ATTACH数据库当一个原子提交。
