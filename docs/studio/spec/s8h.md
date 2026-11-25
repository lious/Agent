## 8H · 垂类不是互斥菜单：三轴、执行图与持久化边界

| 轴/对象 | 有效合同与界面 |
| --- | --- |
| Purpose：做什么 | marketing营销转化、showcase商品展示、story故事、social社媒、tutorial教程、musicVisual音乐视觉。营销、展示必须选择ProductIdentity版本及确认事实；玩法不自行把用途改成营销。 |
| Input modes：从什么起步 | text/script/mediaMontage/i2v/firstLast/nativeContinue/tailFrameBridge/referenceSynthesis/motionTransfer/videoRestyle可组合；例如story＋script＋i2v。每个ShotExecution只有一条实际route，不向同一请求乱塞模式。 |
| PlayRecipe：怎样玩 | 可选hug/miniature/animalHumanized/babyDance，项目可引用多配方，首版每镜至多一个主配方＋多个Craft skill。默认不选；不是所有用途都强加“热门效果”。 |
| 入口 | 首页用途卡→输入来源→可选玩法；素材一键成片直接进入素材分拣，默认allowNewGeneration=false。用户可回到三轴调整；新版本标出受影响镜头、花费和未确认项，不清空旧工程。 |
| 兼容旧Brief | productAd映射marketing；story/social/tutorial/musicVisual保持用途；photoMotion只确定i2v输入，需用户补选purpose后才形成有效新Brief。旧用途和既有Project 2.0结构不原地篡改。旧自由文本事实迁入proposed，不视为已确认。 |
| 独立工件，不谎报Core枚举 | VerticalBrief/WorkflowSnapshot/ShotExecution/PlayRecipe/PromptProgram是独立v1.0.0工件。Project 2.0 Shot.generationMode仍仅t2v/i2v/firstLast/reference；nativeContinue/motionTransfer/renderExisting不得伪填i2v。无法表达的路线Clip.shotId=null，以GenerationRecord和ProjectWorkflowLink.clipBindings保存真实shotPlanId/route。 |
| 跨App | studio_vertical纯Dart合同/图编译/模板；Flutter只做表单/镜头表/审批/候选UI；FFmpeg共享内核负责抽帧/裁剪/拼装，不由Dart做像素实时计算。各App有独立Session/密钥/权限；跨App只有用户明确导入或授予库访问，不能靠相同asset hash偷共享私有分析。 |

完整状态机共用，场景差异在8J—8L逐项定义；“一键”只省重复操作，不绕过事实、肖像、上传与扣费确认。所有模板与示例均为自拟设计，不是模型真实结果、品牌广告或成熟产品模板拷贝。

```text
draft → preflighting → analyzing → planning → awaitingPlan
      → compiling → awaitingApproval → readyToSubmit → generating
      → awaitingQA → readyToApply → applying → applied → delivering → completed
本地素材路径：compiling → readyToApply（remoteJobs=0，不虚构扣费审批）
任意未提交阶段可blocked/failed/needsRebase；运行中取消→cancelRequested；
仅未提交/服务已确认取消的节点cancelled。运行中的晚到结果仍入隔离候选，绝不自动应用。

PreflightReport {sourceProbeHashes[], slotViolations[], rightsChecks[],
 cropPlans[], unsupportedModes[], costUnknownReasons[]}
AnalysisBundle {artifactRefs[], evidenceIndexHash, observed[], inferred[], conflicts[]}
PlanArtifact {beats[], scenes[], shotOrder[], coverage[], frameBudget[],
 shotSpecHashes[], textOverlayPlanHash, audioPlanHash, unresolvedQuestions[]}
CompiledShot {shotSpecHash, profilePin, actualModelId, endpointKind,
 requestJSON, mediaUploadPlanHash, promptHash, warnings[], unsupportedFields[],
 durationContract, outputSemantics, editableOverlayPlanHash}
QAReport {candidateId, sourceHash, identityChecks[], temporalChecks[],
 factualChecks[], audioChecks[], status:pass|fail|unknown, humanDecisionRef:null|Id}
WorkflowCommitPlan {coreBatchHash, workflowSnapshotHash, projectLinkHash,
 readSetHash, writeSetHash, baseRevision:I64, lockedPaths[], acceptedCandidateIds[]}
// DTO中的Evidence/Analysis沿用8A，Money/Quote沿用生成预算模块；路径来自注册表，不从prompt读。

interface VerticalWorkflowCompiler {
 preflight(snapshotHash, sourceProbeRefs, liveRights): PreflightReport;
 plan(snapshotHash, analyses): PlanArtifact; // Agent只产提案；用户确认新版本
 compileShot(snapshotHash, shotId, profilePin): CompiledShot|CompileError;
 quote(compiledHashes, tariffVersion, maxMicros): Quote|PriceUnavailable;
 buildApplyPlan(candidateIds, targetRevision, locks): WorkflowCommitPlan|Conflict;
}
interface WorkflowCoordinator {
 approvePlan(runId, recordVersion, planHash): EventReceipt;
 approveSpend(runId, recordVersion, approvalBindingHash): EventReceipt;
 submitNode(runId, nodeId, expectedCancelEpoch): SubmissionReceipt;
 receiveResult(providerTaskId, resultHash): CandidateReceipt; // 不写时间线
 apply(planHash, approvalRef, expectedProjectRevision): CommandReceipt;
 cancel(runId, expectedRecordVersion): CancelReceipt;
}
ApprovalBindingHash = H(namespace,workflowSnapshotHash,compiledRequestHashes,
 profileCapabilityHashes,mediaUploadPlanHash,rightsEpochs,factVersionHashes,
 targetProjectRevision,readSetHash,quoteId,tariffVersion,maxMicros,cancelEpoch)
// 任何一项改变都使旧批准无效；已付费任务不假称可撤回或退款。

```

| 阶段 | 用户动作→工件/事件→反馈与可逆性 |
| --- | --- |
| 预检/分析 | 选素材→SourceBinding(稳定ordinal/主体角色)→probe与RightsChecked；未知尺寸/损坏/缺授权阻断。FFmpeg分析＋8A OCR/视觉/ASR用同一语义缓存键，文本文件不可信指令不得改变工具权限。用户可移除引用，不等于删源文件。 |
| 规划/确认 | 镜头表显示每镜用途、角色、动作、素材路线、时间预算、声音、事实来源。导演/编剧/摄影Agent可异构模型；PlanProposed后用户逐镜接受、改时长、删镜头、锁字幕。未经确认的下一阶段不启动付费。 |
| 编译/批准 | 右侧逐镜展示最终prompt、参数、硬/软控制、上传文件与是否带原声；用户override存独立版本。QuoteUnavailable时不出现可扣费确认按钮。只允许有有效期/币种/上限的显式批准。 |
| 生成/QA | 每镜候选网格显示来源、prompt版本、实际时长、费用状态、QA证据；选候选/对比/局部重做只影响该依赖闭包。机器QA不保证识别所有变形或虚假功效；事实/真人/婴儿必须人工审片。 |
| 应用/交付 | 接受候选→预览NLE diff→受信CommandCoordinator一次批量提交：attachArtifacts＋既有合法insert/trim/字幕等命令；映射在同工作区事务内绑定。手工锁字段冲突则整体不提交。导出前复查事实有效期/授权/缺资源/交付preset；保存归档固定revision，不重跑付费任务。 |

规划版本不是Project revision。WorkflowSnapshot先写CAS并校验durable，然后trusted coordinator在既有core batch unit-of-work中写ProjectWorkflowLink与receipt；失败只产生可GC孤儿工件，不能出现已剪辑但无来源映射的半提交。禁止新增不受审setExtension、任意SQL或向commands.payload_format塞新枚举。WorkflowRun只存工作区任务状态，私有Session用既有outbox投影。另存为/fork重映射projectId与clipBindings；恢复旧规划不自动回滚实际时间线，readSet不符显示needsRebase并显式挑选patch。
