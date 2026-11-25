## 5D · 归档、备份与恢复：闭包、身份和不可信输入

| 模式/决策 | 可编码规则与结果 |
| --- | --- |
| 逻辑库归档 | ArchiveService.setLibraryArchived先停止接受新文档手势并排空已提交队列，取expectedHead/recordVersion CAS，将library_state=archived并记Lifecycle事件；工程revision不因列表状态变化而增加。归档库隐藏于活跃页、打开只读、可恢复active；不删CAS，不撤销/重提云job。已有job仍可记候选/账单，但不能自动attach到归档文档。恢复活跃态后仍需审阅候选。 |
| 固定revision可移植归档 | exportPackage与逻辑归档是两个独立按钮。plan固定R和完整docHash，生成中可选“归档当前R，列出未完成项”或返回等待；不替用户取消付费任务。creativeCompletion=pendingJobs时明确“已归档当前版本，尚有未完成生成，包内不含其未来输出”；任务后来完成不改变已发布包，需新plan。归档中继续编辑只影响新R。 |
| originals / proxies / linked | originals收集可合法再分发的accepted原件和生成媒体；proxies仅收可用代理与映射，manifest.packMode=linked且missingExternalRefs列缺原件Asset ID；linked只收文档和已选小资源，外链locator只保ID，换机需重链接。沿用2.0的embedded/linked枚举，不发明proxyOnly core enum。sourceCompleteness分别selfContained/proxyOnly/externalRefs/incomplete；只有全体必需编辑/渲染源含可用字体闭包齐全才selfContained，不能因ZIP写完称资源完整。模型复现缺失另以omission.impact=reproGeneration报告，不伪称已打包云模型或权重。 |
| ResourceClosureResolver.walk | 按固定Project JSON的全部Asset/Blob/retainedSources、Nest定义、效果mask、caption字体、被pin的CharacterPack/Look/引用图、Craft SkillPackage版本/步骤模板、music/stems、license/证据显式引用边遍历并按(ns,hash)去重。每扩展注册ReferenceWalker；未知必需扩展不能证明闭包时报UNRESOLVED_EXTENSION_CLOSURE，禁止自包含标记。可重建代理/缩略图/render缓存按选项排除且登记，不误当source。循环引用失败REF_CYCLE。 |
| 再分发/执行许可分开 | 字体/权重/LoRA等组件许可逐项记录redistribution事实，受限/unknown按1C允许用户选定收集并附风险清单，不自动偷带。角色真人参考图/voice/用户素材仍需真实共享同意，缺失不得收集。LoRA默认仅base fingerprint等引用；模型引用不自动下载。YuE2托管缺商业授权按1C默认风险放行，不因归档许可说明伪造授权；权利记录/许可证据本身有隐私时只导出经同意的脱敏摘要。 |
| 会话和删除 | 默认sessionPolicy=excluded且manifest.sessionArchive=null，包内任何sessions正文/摘要/FTS/RAG/分析缓存/凭据/审批/lease/下载token/临时文件均不允许残留。headersOnly或selectedContent按原SessionArchive2.0导出当前允许内容及origin→local revision map，commandBodiesIncluded=false；所有旧Run为historical/interruptedOnExport。每次从干净staging构建，不复用上次含会话目录。分析证据只在用户另选制作依据且通过权限时入包；不把通用缓存顺手压入。 |
| 遗忘屏障与流式竞态 | plan和publish都核验当前privacy/rights epoch。原固定R若含已禁止保留/导出的正文或派生资源，报SNAPSHOT_PRIVACY_BARRIER，改选已脱敏当前R或显式建sanitized fork；不偷偷改同一R的JSON/hash。删聊天但明确保留的已接受工程副本按既有保留决定处理，不擅自删工程。导出中删除先停传并失效plan；已经传到provider的字节只能请求清理/提示，不能承诺远端撤回。已发布本地/外部备份列在删除影响单；已删除正文不得由旧包导回，旧备份需live tombstone过滤后只读或sanitized fork。 |
| 空间/进度/取消 | ZipPlanner.upperBound使用受控ZIP64 writer实际条目头/中央目录/压缩上界计算；大媒体默认ZIP_STORED，元数据可压缩。按volume聚合新增CAS字节+staging上界+必要良好旧副本保护+安全余量，不假设跨卷rename、不把hash相同的媒体重复计入CAS。目标空间unknown先提醒并保守新文件写；任一步ENOSPC安全中止。进度分别显示扫描/收集/写入/校验/发布；总bytes未知不编百分比。取消发生publish前无目标替换，publish后返回实际结果并保留receipt。 |
| 增量备份与GC | BackupStore以内容寻址snapshot+blobs/可选定长4MiB分块清单增量保存，完整内容hash仍为验证依据；不重复存已有blob/chunk，不备份私有session DB/凭据。根集含当前head、有效undo/redo、保留branch/checkpoint/namedVersion、最后良好回执、backup、归档固定R、未完成job/不确定publication pin、库版本冻结。标记到不可达才进gcPending，普通宽限7天；privacy拒读立即生效另作安全清除，不等宽限。未知扩展无法枚举引用时保守pin并阻止假完整归档。 |
| 保留策略 | 默认未命名checkpoint保留最近100个或7天窗口（取并集），显式保存点最近20个且30天，命名版本不自动淘汰；备份启用后本机编辑活动至多每15分钟增量一次，保留7日+4周+命名版本。都是设计默认而非系统定时唤醒保证。2GiB元数据软预算触发清理建议，不淘汰唯一良好基线/命名版本/未决job以强行达标。删除项目另走明确回收站30天，归档从不启动这个倒计时。 |
| 同工程恢复版本 | RestoreService先生成精确before/after diff与受保护字段列表，固定source checkpoint/hash、当前expectedRevision、epochs及consent。确认后单个生命周期事务生成head+1；重用仍存在的不可变旧实体定义版本，与第5a undo一致；后续编辑取该ID历史max(version)+1。不倒退事件seq、不替换整个SQLite、不恢复旧审批；before快照pin提供新revision的undo。当前锁定手调字段默认阻断，用户可明确确认覆盖或改为fork；AI不能发restoreVersion。 |
| fork/导入副本 | 默认新projectId和当前授权namespace，revision=0；ReferenceRemapper按registry给项目内实体ID建立映射并更新所有local refs，blobHash/库版本pin/模型profile fingerprint保留。provider jobId仅历史溯源，不变为poll/resume绑定；candidate provenance映射成历史只读引用。origin(projectId,R)→(newId,0)记ImportMap，可选会话通过此图映射，无history的旧revision不可用。未知扩展若需实体重映射而无remapper，拒绝可写fork，不猜文本替换；可保留原包只读。 |
| 冲突/未来/降级 | 相同projectId+revision+hash是重复导入，询问打开现有或创建fork；同ID同revision异hash报IDENTITY_COLLISION，不能覆盖。未来schema先按可识别外层限量扫描，未知核心只读元信息/保留原包，不解释并执行；已知schema缺media/font/plugin/effect/capability走现有缺资源/只读/明确替代计划，不静默烘焙或换字。迁移仅副本纯函数并校验，成功才登记新本地工程；不删除原归档。 |

```text
// safe_import.cpp：先扫描，不向用户目标目录直接解压；P1不支持归档内符号链接。
ImportLimits defaults = {maxEntries:100000, maxExpandedBytes:50GiB,
 maxSingleEntryBytes:20GiB, maxSnapshotJsonBytes:32MiB,
 maxCompressionRatio:200, maxPathUtf8Bytes:1024, maxDepth:32};
// 默认是安全产品策略，可在单次预检后显式调大；不是解码能力/ZIP格式极限。
for entry in zip.centralDirectory:
 reject encrypted entry / symlink / hardlink / device / fifo / unexpected directory metadata;
 normalize NFC+casefold collision key, reject duplicate key, drive/UNC/absolute path,
 backslash, NUL, colon, empty component, dot/dotdot, reserved Windows name/trailing dot/space;
 validate entry counts/declared expanded size/ratio, ZIP64 overflow and local-header agreement;
// 不能只信centralDirectory：每个解压chunk继续累计真实bytes与预算，超限中止。
extract to app-private quarantine via dir-relative no-follow handles;
never auto-fetch external URL, resolve locator, execute plugin, install model or open script;
verify checksums exhaustive set (except itself), size/hash, manifest+snapshot/schema+semantic;
apply current namespace rights/privacy overlay BEFORE indexing/thumbnail/context/preview;
only then show import plan and obtain destination/overwrite/fork/capability choices;
commit local registration last. Partial import cannot become active project.
// ZIP checksum是损坏检测不是可信签名；外部签名也不替代Schema/路径/许可/用户确认。
// 用户明确同意前，任何同名用户文件不得删除或覆盖；首次导入也不自动联网补资源。
```
