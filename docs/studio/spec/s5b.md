## 5B · 保存不是一个布尔量：权威状态、接口与自动保存

| 动作 | 持久化事实、UI与非等价项 |
| --- | --- |
| 编辑事务commit | 一次完成的剪辑手势/命令先冻结after文档与逆补丁，保证所需CAS文件落盘，再在同一workspace SQLite事务写commands/revisions/events/receipts/project_heads。WAL+synchronous=FULL提交成功才ACK；UI为“已记录到本机 · R22”。拖动中的临时预览/未提交文字输入不是head，必须另示“正在编辑，尚未记录”。禁止SQL内启动云副作用。 |
| 磁盘durable | 不是另一条内容revision：headRevision只来自已成功提交且同步ACK的project_heads.revision；正常打开时durableRevision=headRevision，是派生显示，不另持久化一列。硬件/VFS撒谎、介质损坏不在绝对承诺内。提交结果未知时暂停新写，先凭commandId/receipt查询，不能盲重试生成。 |
| 自动恢复点checkpoint | 在已持久事务上登记不可变Checkpoint，物化或复用同hash的文档JSON、验证引用、更新latest checkpoint指针；便于快速打开/备份和日志保留，不是SQLite WAL checkpoint，也不是把素材重拷一次。checkpointRevision由指针所指记录得到，可能落后head，不表示这些编辑未落盘。 |
| 显式保存Cmd/Ctrl+S | 工程库管理模式：saveManaged写checkpoint和显式保存回执，显示“已保存到本机工程库 · R22”。用户明确关联了外部文件时按钮改为“保存到〈文件〉”，saveBoundPackage冻结R并更新工程包，直到StoragePort回执才显示对应成功。未关联不暗示已经写出.studioproj。 |
| 另存为/命名版本 | 另存为提供“新工程副本（默认fork新ID）”和“将当前工程保存到新位置（保留ID并显式切换binding）”；不静默覆盖已有文件。命名版本只是label→不可变Checkpoint的长期pin，不复制大媒体，不等于fork或回滚。名字唯一冲突提示改名，不覆盖旧命名版本。 |
| 备份/归档/成片/同步 | 备份是独立校验、按策略保留的恢复根；逻辑归档是库状态；可移植归档是固定R的资源包；成片导出是渲染结果，不能替代可编辑工程；同步只传输已提交快照/事件且单独有远端ACK。显示“已写入云盘provider”不等于“其他设备已同步”。 |

```text
// studio_document/persistence/；均为设计合同，不是已实现App代码。
SaveCoordinator.request(SaveRequest) -> Future<SaveHandle>
SaveHandle {requestId, operationId, capturedRevision:U64, capturedSnapshotHash:Hash}
SaveCoordinator.watch(operationId) -> Stream<SaveProgress|SaveReceipt|SaveFailure>
SaveCoordinator.cancel(operationId, expectedCancelEpoch) -> Cancelled|AlreadyPublished|PublicationUncertain
AutosaveScheduler.onDurableCommit(projectId, revision, monotonicNow)
AutosaveScheduler.onLifecycle(background|close|memoryPressure) -> FlushResult
CheckpointStore.capture(projectId, revision, epochs, writerFence) -> Checkpoint
ProjectPackageWriter.prepare(PreparedArchivePlan, pinLease, cancel) -> VerifiedStaging
ProjectPackageWriter.publish(VerifiedStaging, TargetPublishLease, consent) -> StoragePublication
ArchiveService.setLibraryArchived(projectId, expectedHead, expectedRecordVersion, archived)
ArchiveService.plan(projectId, revision, ArchiveOptions) -> PreparedArchivePlan
ArchiveService.export(planHash, targetBindingId, consentRefs, cancel) -> SaveHandle
RestoreService.inspect(packageToken, ImportLimits) -> VerifiedImport|ImportReport
RestoreService.plan(sourceCheckpoint, targetProject, mode:sameProject|fork) -> RestorePlan
RestoreService.apply(planHash, expectedRevision, consentRef) -> DocumentCommit|ForkReceipt
DocumentLifecycle.open/close/acquireWriter/releaseWriter -> LifecycleView
StoragePort.probe(targetToken) -> StorageCapabilities
StoragePort.createStaging(targetToken, expectedBytes), writeChunk, flushFile, close
StoragePort.publish(stagingToken, expectedTargetVersion, overwriteConsent) -> StoragePublication
StoragePort.readBackHash, syncParent, reconcile(publicationIntent), abortStaging

StorageCapabilities {realm:local|provider|network|unknown, atomicFileReplace:bool,
 conditionalReplace:bool, fileSync:bool, directorySync:bool, readBack:bool,
 createSibling:bool, freeBytes:U64|null, coordination:apple|windows|none,
 durabilityContract:localFsync|providerAck|unknown}
StoragePublication {targetToken, versionToken:string|null, artifactHash:Hash,
 durability:localDurable|providerAcceptedVerified|providerAcceptedUnverified}
SaveProgress {operationId, phase, capturedRevision, bytesDone:U64,
 bytesTotal:U64|null, entriesDone:int, entriesTotal:int, cancelable:bool}
LifecycleView {openState:closed|opening|recovering|ready|quiescing|closing|failed,
 access:readWrite|readOnly, libraryState:active|archived|trashed,
 headRevision:U64|null, checkpointRevision:U64|null, targetSavedRevision:U64|null,
 pendingCommit:bool, packageBehind:bool, lastError:SaveFailure|null}
// revision/dirty类值均为源表/队列派生view，不作为另一份可写状态。
// closed->opening->recovering(按需)->ready->quiescing->closing->closed；
// opening/recovering失败->failed，用户选安全只读副本或重试；不自动覆盖原库。
// libraryState与openState正交；archived可ready但access只读。归档/关闭先quiesce新文档命令，
// 候选任务继续运行，checkpoint可继续；未获ACK草稿未明确处理前不进入closed。
SaveFailure {operationId, code, phase, retryable:bool, retryAfterMs:int|null,
 suggestedAction:retry|chooseTarget|regrant|freeSpace|inspectRecovery|readOnly,
 publicationOutcome:notPublished|unknown|published, checkpointRef:Id|null}
ArchiveOptions {mode:originals|proxies|linked, sessionPolicy:excluded|headersOnly|selectedContent,
 historyRevisions:U64[], includeProxyCache:bool, maxExpandedBytes:U64,
 redistributionPolicy:onlyAllowed, externalLocatorPolicy:idsOnly}
PreparedArchivePlan {planHash, projectId, revision, snapshotHash, options,
 entries:InventoryEntry[], omissions:Omission[], pendingOperations:PendingOperation[],
 epochs:{privacy:U64,rights:U64}, capabilityHash, closureResolverVersion,
 requiredBytesByVolume:[{volumeToken,bytes:U64}], consentProjectionHash}
// revision/bytes/fence/epochs穿过JSON/FFI均为十进制字符串；DB内部int64。
// Dart编排不可变文档/策略，native StoragePort worker做文件IO/ZIP/hash/sync；
// 不在UI isolate拷贝GB媒体，不占用FFmpeg音频回调或实时渲染线程。
```

| 状态/算法 | 唯一来源与实现约束 |
| --- | --- |
| dirty与保存标记 | 不存dirty/durableRevision/userSavedRevision/snapshotRevision四套计数器。head从project_heads取；checkpointRevision从last_checkpoint_id联表取；targetSavedRevision从目标last_receipt_id取；userSavedRevision仅为最后显式保存receipt关联revision的查询结果。pendingCommit来自瞬时手势/命令队列；packageBehind=(head与该target receipt的revision/hash不同，或闭包/策略指纹不同)。自动恢复点不清除外部文件的packageBehind。 |
| 默认自动策略 | onDurableCommit设置firstPendingMonotonic（仅首次）和lastEdit；deadline=min(lastEdit+2s,firstPending+30s)，或积累50次完成事务立即触发，任一先到。启动后先取最新durable R；运行中又有编辑只排一个后继最新checkpoint。2s/30s/50是平衡交互/元数据IO的设计默认，不是基准结论；用户范围见policy schema。系统挂起/磁盘故障时最大间隔不构成硬保证。 |
| 后台/关闭 | 后台/切工程/关闭立即请求checkpoint，不等待长生成，不等待ZIP。关闭先处理尚未提交手势/文本：提交并等本机ACK，或用户明确丢弃草稿；失败留在文档并给“重试/另存恢复副本/放弃未记录修改”确认。移动OS到期前仍只能承诺已有ACK，不能靠无限后台task。桌面退出时外部包未完成提供等待/取消打包并保留本机恢复点，不伪称已写外部文件。 |
| 包自动更新 | 默认externalPackageAuto=false，明确显示“自动保存在本机；工程文件待更新”。用户可开启已授权本地目标的合并更新（30s idle、120s最大尝试、单任务），触发不重复复制CAS中的原件。provider/网络目标P1不后台自动覆盖；必须显式保存并确认上传闭包。目标被OS同步服务托管/性质未知也按provider谨慎处理，不假定路径是file就无上传。 |
| 保存中编辑/合并 | capture R22后UI可继续提交R23；完成只记录receipt(R22)，绝不赋值head=22或dirty=false。每project一个editor writer；每target一个publisher。只对kind/target/固定R/planHash/epochs全部相同请求合并，requestId经waiter映射同operation。排队的自动checkpoint可替换为最新R；命名版本、固定R归档、不同许可或会话选择绝不偷换快照。 |
| 锁与fencing | 先取本机OS协作锁再BEGIN IMMEDIATE提升writer_fence并登记owner UUID；命令提交与发布前都验fence、owner、文档状态、expectedRevision/target version。不能仅凭过期时间抢活锁；崩溃后OS释放，接管者对未决publication先对账。保存prepared阶段不长持SQLite写事务，publish短临界区与当前policy epoch核验共用串行协调器；旧worker结果报STALE_WRITER，不碰head/目标。不同App不共享私有workspace；显式App Group共享库也必须同协议和namespace授权。 |
| 生成中的资源 | 长视频/音乐/分析任务在workspace outbox/候选表持续写自己的进度，不制造项目revision或重复写权重。媒体先staging，hash/size/probe通过后一次publish CAS，再允许attachArtifacts。处理中候选不伪造ready Asset、不增加pending enum；计划镜头可为Shot+Gap，未完成任务只在归档描述记录logicalId和stateAtFreeze，绝不含可resume远端token。成片导出对未就绪源报PENDING_MEDIA；工程保存允许并明确“有未完成镜头”。 |

持久化边界：portable Project JSON、私有Session DB和媒体/角色/技法CAS分离。workspace SQLite保存工程头、命令、保存/接受回执及投影outbox；Session DB保存对话/Run/上下文，库索引保存共享资源元数据；同进程可由宿主选物理隔离，但跨库不承诺SQL原子。accept的“accepted group IDs”以workspace receipt为权威，Session索引落后时按receipt显示已接受而非重提。跨库资源先取得持久pin再提交工程，回执后转交长期pin；崩溃留孤儿pin可对账，不能先释放源pin制造GC窗口。独立Session备份或原始DB不进入工程包；可选会话导出另造经当前遗忘策略过滤的SessionArchive。
