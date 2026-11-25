## 8B · 专业制作流程：工件、依赖、摄影意图与确定性剪辑分层

这里借鉴Adobe公开制作阶段、shot list与split-edit方法，细化为本产品自拟工作流，不假称主流产品内部Agent也是这样实现。小广告可以合并步骤显示，但brief、叙事意图、镜头计划、生成请求和剪辑结果仍是独立版本；不是让用户为了15秒广告填一份长片论文。

| 阶段/交接 | 工件内容与进入条件 | 确认/执行与失效 |
| --- | --- | --- |
| 开发：Brief→logline/treatment | WriterAgent读取有效事实和用户目标，输出一句话logline、主题、受众承诺、开端/转折/结尾的treatment；标事实来源与待定项。 | 用户确认目标、事实/广告承诺、主角与叙事方向；自动起草不等于批准生成。产品广告用hook→proof→CTA，叙事片用欲望→阻碍→选择→结果，不套同一节拍。 |
| 叙事节拍→分场脚本→剧本拆解 | ScriptScene{sceneId,intExt,locationId,timeOfDay,characterIds,beats,action,dialogueIds,requiredProps}；Breakdown按角色/道具/场景/声音/连续性列需求；分场文本与拍摄顺序分开。 | 用户确认剧本/角色变化；自动检查时长和缺覆盖镜头。剧本改台词只失效相关VO/字幕/口型候选，不自动推翻无关场景。 |
| Bible＋导演阐述 | ContinuityBible固定角色外观参考/服装/道具状态、场景布局与光向、轴线/画面方向；DirectorStatement说明视点、情绪弧、反差策略、何处克制/何处打破惯例。 | 确认角色肖像/参考权利和视觉方向；不是以seed承诺一致。各镜依赖Bible的字段选择器，不以整个文档hash粗暴失效全部。 |
| 摄影/镜头表→分镜→animatic | DPAgent输出有目的的ShotDesign和coverage：主镜/反打/反应/插入；Board是草图/授权静帧；Animatic用静帧与临时音按准确时长排演，未付费也能检查节奏。 | 确认镜头表、节奏/轴线例外、候选数、上传与费用；可自动校验镜长总和/安全区。分镜图不是已生成电影画面，临时音不能带无权利音乐导出。 |
| 逐镜生成/选take | GenerationWorker按一镜一请求留handles；DP/ContinuityAgent回传观察和缺陷，用户比较候选、选take或只改一个变量重试。 | 每次有新收费/上传须绑定具体请求审批。自动质检只能给建议，不自动让“质量不够”无限烧钱；锁定手改字段、原候选不被覆盖。 |
| 粗剪→精剪→声音/调色→QC交付 | EditAgent提议组装与节奏；粗剪验证叙事，精剪到帧/sample；SoundPlan独立VO/环境/拟音/音乐bus；GradePlan仅用支持的色彩算子。最终锁定sequence/revision/preset。 | 接受patch才改工程；人工字幕/trim永远优先。字体组件商业许可缺口仅风险提示；用户素材权利/肖像声音同意、失效费用上传批准、缺媒体/HDR未处理仍阻导出；按第7节同RenderRecipe预览/输出。专业流程不意味着P1已具备对白ADR/自动拟音/电影级调色的所有工具。 |

```text
// packages/studio_production/{stage_graph,shot_design,prompt_compiler}.dart
// 可迁移领域数据，与云provider和本地聊天DB分离；新工件合同均version=1.0.0。
StageKind = brief|treatment|beatSheet|sceneScript|breakdown|bible|directorStatement|
            shotList|storyboard|animatic|generationPlan|assembly|fineCut|sound|grade|delivery
StageArtifact {id,kind,schemaVersion,version:I64,projectId,branchId,bodyRef:Hash,
  dependencies:DependencyRef[],sourceIntentIds:Id[],baseTimelineRevision:I64,
  createdByAgentId,createdByRunId,state:draft|proposed|approved|stale|superseded|revoked,
  approvalRef:null|Id,manualFieldLocks:JsonPointer[],createdAt:Timestamp}
// state是ArtifactRecord投影；bodyRef内容不可变。正文类型由kind对应已注册schema。
ProductionPlan {id,version:I64,briefRef,stageRefs:Id[],shotDesignRefs:Id[],
  editPlanRef,continuityBibleRef,outputPresetId,targetDuration:Q,
  undecidedQuestions:string[],protectedPaths:JsonPointer[]}
ShotDesign {id,version:I64,projectShotId,sceneId,narrativeBeatId,purpose,
  subjectRefs:EntityRef[],oneVisibleAction,emotionIntent,settingRef,propStateRefs:Id[],
  framing:ECU|CU|MCU|MS|MLS|WS|EWS,angle:eye|high|low|overhead|canted,
  lensIntent:{fullFrameEquivalentMm:null|number[8..600],
    subjectDistanceM:null|number(0..1000],fStop:null|number[0.7..32],
    focusTarget:null|string,depthOfField:deep|shallow|unspecified},
  cameraMove:{kind:locked|pan|tilt|dolly|truck|orbit|handheld|zoom,
              direction:null|string,speed:slow|medium|fast,description},
  blocking:{startPose,endPose,screenDirection:L2R|R2L|toward|away|still|unknown},
  light:{motivation,keyDirection,quality:hard|soft,palette:string[],timeOfDay},
  continuity:{axisId:null|Id,axisSide:A|B|onAxis|unknown,eyelineTarget:null|Id,
    matchActionTo:null|Id,intentionalBreakReason:null|string},
  timelineDuration:Q,generateDurationSeconds:uint[2..15],headHandle:Q,tailHandle:Q,
  referenceInputs:Reference[],dialogueRef:null|Id,soundIntent,textOverlayRefs:Id[],
  constraints:{hardEditorial:string[],softGenerative:string[]},
  dependencySelectors:DependencyRef[]}
EditPlan {id,version:I64,orderedShotIds:Id[],cuts:CutPlan[],rhythmNotes,
  audioPlans:SoundCue[],captionAnchors:CaptionAnchor[],gradeRef:null|Id,
  baseTimelineRevision:I64,lockedPaths:JsonPointer[]}
CutPlan {id,leftShotId,rightShotId,at:Q,
  kind:hardCut|dissolve|matchCut|J|L|intentionalJump,
  audioOffset:Q,matchAnchorRefs:Hash[],reason,acceptance:manual|advisoryCheck}
// J/L是策划类型，不新造Project.Transition.kind；编译为独立音画Clip范围。
// audioOffset是相对画面切点的有符号Q：J<0，L>0；其它切法为0。
// timelineDuration>0，handles≥0；rate1时生成秒数≥sourceIn+timelineDuration+tailHandle，
// 变速则按既有TimeMap端点与handles算源需求，不用简单片长乘近似fps。
SoundCue {id,assetRef:null|EntityRef,scriptRef:null|Id,
  role:dialogue|voiceOver|ambience|foley|music,range:Range,busId,
  sourceRange:null|Range,rightsId:null|Id,gainEffectRef:null|Id,temporary:bool}
CaptionAnchor {captionId,clipId,localRange:Range,policy:clipLocal|sequenceAbsolute}
StagePlanner.plan(kind,inputRefs,intentSlice,currentRevision)->StageProposal
ProductionDependencyGraph.invalidate(changeSet)->InvalidationReport
FilmPromptCompiler.compile(ShotDesign,providerCapability,templateVersion)->
  {promptDraftRef,requestRef,fieldMappings:FieldMapping[],warnings:CompilerWarning[]}
FieldMapping {fieldPath,handling:api|promptSuggestion|nle|unsupported,outputPath:null|string}
// 不支持的required能力返回CAPABILITY_UNSATISFIED，不能丢字段后继续收费。
StageCommitCoordinator.accept(stageProposal,expectedVersions,expectedRevision)->Receipt
// 确认导演阐述只更新StageRecord；接受组装才以既有Command.batch产生Project revision。

// 当前闭合Project schema不变：Shot.camera仍只有size/motion/lensIntent。
// 更丰富参数存版本化ShotDesign工件；编译时映射上述三个字段，不偷偷添camera.fStop。
Project.extensions["studio.production.v1"] = {
 "schemaVersion":"1.0.0","manifestHash":"sha256:<hash>"
}
ProductionManifest {schemaVersion:"1.0.0",planRef:Hash,
 artifacts:{id,kind,version:I64,blobHash:Hash,dependencyBlobHashes:Hash[]}[],
 evidenceExport:referencesOnly|selectedContent,projectRevision:I64}
// 这是已声明扩展的合同，不是新Project根字段。manifestHash必须指向项目blobs内登记的blob；
// 其闭包由ExtensionResourceAdapter枚举、校验、pin/GC，未知扩展原样保留、不擅自GC。
// 制作计划是advisory元数据，不改变底层画面：缺feature的App仍能NLE/播放已成时间线，
// 但禁改制作计划/重编生成；导出保留opaque扩展。需要新渲染语义时才加入requiredFeatures。
// session的branchId/agent审批只在本机StageRecord；导出StageDocument剥离这些运行列，
// 仅保可移植作者说明/意图事实与revision映射，不迁移批准与sourceUseGrant。
```

```text
// StageDocument.body的封闭联合，避免只有“schema注册”名字却没有正文定义。
// 每个对象所有所列字段必需，可空显式null；基础ID/长度/数组规则同8A。
StageDocument {schemaVersion:"1.0.0",id,version:I64,kind:StageKind,
  body:StageBody,dependencies:DependencyRef[],sourceIntentIds:Id[]}
StageBody(kind) =
 brief: ProjectSchema.Brief
 treatment: {logline,theme,dramaticQuestion,paragraphs:string[],audiencePromise,
             factEvidenceRefs:EvidenceRef[],unknowns:string[]}
 beatSheet: {beats:{id,sceneId:null|Id,order:uint,newInformation,emotionalTurn,
                    shotIds:Id[],durationBudget:Q}[]}
 sceneScript: {title,language,scenes:{id,intExt:INT|EXT|INT_EXT,locationId,timeOfDay,
   beatIds:Id[],actions:{id,beatId,text}[],
   dialogues:{id,speakerCharacterId,deliveryIntent,textRef:BodyRef}[],estimatedDuration:Q}[]}
 breakdown: {requirements:{id,sceneIds:Id[],kind:character|wardrobe|prop|location|sound|vfx,
   subjectId:null|Id,description,rightsId:null|Id,continuityStateRef:null|Hash,mandatory:bool}[]}
 bible: {characters:{id,appearanceRefs:EntityRef[],wardrobe,voicePolicy,
                      movementNotes,forbiddenChanges:string[]}[],
   locations:{id,layoutDescription,axisIds:Id[],lightDirection,palette:string[]}[],
   axes:{id,subjectIds:Id[],sideADescription,screenDirections:string[]}[],
   props:{id,assetRef:null|EntityRef,states:{beatId,stateDescription}[]}[]}
 directorStatement: {pointOfView,theme,emotionalArc:string[],visualMotifs:string[],
   soundCounterpoints:string[],continuityExceptions:{shotId,rule,reason}[],restraintNotes}
 shotList: {shotDesignRefs:Hash[],coverageGroups:{sceneId,
   role:master|reverse|reaction|insert|establishing,shotIds:Id[]}[],shootOrder:Id[]}
 storyboard: {panels:{shotId,imageRef:null|EntityRef,description,
                      frameAnchorRefs:Hash[],state:sketch|reference|generated|missing}[]}
 animatic: {sequenceRef:EntityRef,sourceBoardRef:Hash,placeholderAssetRefs:EntityRef[],
            duration:Q,temporarySoundIds:Id[],validationReportRef:null|Hash}
 generationPlan: {requests:{shotId,promptDraftRef:Hash,providerProfileRef:ProfileRef,
   candidateCount:uint[1..4],durationSeconds:uint[2..15],uploadPlanRef:Hash,
   quoteRef:null|Id,state:unquoted|awaitingApproval|approved|submitted|stale}[],
   totalGenerationSeconds:uint,approvalBindingHash:null|Hash}
 assembly: EditPlan
 fineCut: EditPlan
 sound: {cues:SoundCue[],audioBusIds:Id[],dialoguePolicy,
         rightsCheckRef:null|Hash,validationReportRef:null|Hash}
 grade: {workingColor:"linear-rec709",outputColor:"rec709",lookIntent,
         perClipEffectRefs:{clipId,effectIds:Id[]}[],
         hdrPolicy:reject|confirmedToneMap,matchCheckRef:null|Hash}
 delivery: {sequenceId,revision:I64,presetId,renderRecipeHash:null|Hash,
   validationReportRef:null|Hash,state:blocked|ready|rendering|failed|delivered,
   rightsIds:Id[]}
// 结构Validator检查kind/body、required/null/enum/范围；语义Validator另验所有ref、
// 总镜长/handles、shot与scene唯一关系、editPlan锁/音轨碰撞、权利/能力/有效意图。
// Stage状态：draft→proposed→approved；正文修改创建新version，旧版superseded；
// 依赖变更approved→stale，权限撤销→revoked，不自动由stale恢复approved。
// accept错误：DEPENDENCY_STALE/INTENT_CONFLICT/CAPABILITY_UNSATISFIED/
// MANUAL_LOCKED/REVISION_CONFLICT/HANDLE_UNAVAILABLE/QUOTE_REQUIRED/APPROVAL_STALE；
// accepted Stage引用与Project内容在workspace文档事务中同成败；
// 独立Session/资产库索引通过receipt/outbox更新，允许短暂投影滞后，不伪称跨DB原子。
// 安全plan可重算，批准与付费不能自动重试。
// 普通“删镜头”是规划动作名，执行映射updateCreative.remove + delete，不新增RemoveShot payload。
```

异构Agent不是一个云聊天账户套多个角色名：Writer/Director可用既有deepseek-v4-pro文本profile；DP/Continuity用deepseek-flash图像profile；Editor用本地Qwen3-1.7B；ASR用本地Whisper；视频由Wan GenerationWorker生产。每个Agent有独立session分支、模型、context、工具grant与预算子账，交接仅StageArtifactRef＋有效意图切片＋证据引用；Director拿到分析后的文本可整合，不因此变成视觉模型。某角色可以由同一模型的独立Agent承担，不能声称必须每工种训练一套模型。

| 技法与使用条件 | 在哪执行/校验/不能保证 |
| --- | --- |
| 镜头参数不是关键词堆砌 | 先选叙事功能，再定景别/视点/单一动作，必要时才写焦段/景深/运动。焦段必须注明等效画幅；透视取决于机位/主体距离，不能说固定机位只换85mm就改变透视。ShotDesign中的35mm/f2.8/2m是语义意图，不是Wan真实物理摄影机API；模型可忽略，返回SOFT_CAMERA_CONTROL。精确文字/Logo在NLE，不能靠prompt拼写保证。 |
| 叙事节拍、反差与蒙太奇 | 序列级BeatSheet决定信息先后、伏笔回收/反应镜头、平行剪辑或时间省略。视听反差须写目的，例如紧张走廊配平静钟声制造不安，而非一律大鼓/冷暖撞色。蒙太奇跨多个独立Shot再由EditPlan定切点；单镜prompt只描述此刻的可见动作，不向5秒模型塞完整三幕和三次转场。硬节奏由NLE时长完成，情绪弧由选take与剪辑验收。 |
| 180°/30°/视线/动作匹配 | 连续性Bible记录对话轴线与银幕左右；反打同侧、视线朝目标、动作切在同一动作相位。30°是避免近似机位跳切的经验原则，不作为物理真理；故意jump cut/越轴可写intentionalBreakReason。缺空间/姿态证据时QA=unknown而非通过；自动看图只给advisory，用户验收。不得为满足规则自动翻转印有商标/文字的画面。 |
| J/L cut | 画面切点c：J把下一镜音轨起点放c−j，L把前镜音轨终点延至c+l，j,l>0。须有源音head/tail handles与可写音轨；B音sourceIn=0.5s，j=0.4s可取0.1s；j=0.6s越界拒绝HANDLE_UNAVAILABLE，或明确改用独立授权环境声。通过unlink/独立audio trim+move的受审batch实现，含锁定/碰撞/bus检查；不是加一个视频dissolve，也不是让生成模型“执行J cut”。 |
| match cut/切换/节奏 | 相似形状/运动/构图切换需两端FrameAnchor和出入动作相位；prompt只帮助生成可选素材，NLE选切点后用户对照，无法保证无缝。P1支持hard cut/dissolve及上述split edit；复杂wipe/morph若能力未注册报UNSUPPORTED_EDIT_TECHNIQUE，允许改已支持切法但须用户接受。节奏按beat marker/叙事停顿精确落帧，音频落sample，不以转场越多越电影感。 |

| Profile/公开依据 | 本轮编译边界 |
| --- | --- |
| Wan2.6 t2v / i2v / i2v-flash（主生成profile） | 沿用第8节已核验model IDs、2..15整数秒与能力版本。t2v可从主体/场景/动作构造；i2v优先运动与首帧已有外观。镜头/灯光/连续性是promptSuggestion；duration/size或resolution/seed/negative等只按各profile真实参数表传。不能因t2v有size就给i2v传size。当前首尾帧/多参考能力不足即阻该模式；同seed跨模型无一致性保证。 |
| Runway Gen-4公开prompt guide（比较，不是新增已接通服务） | 此指南描述I2V、5/10秒、简短正面动作描述、不使用negative prompt；不能把Wan negative原样复制，也不把旧指南当最新Gen-4.5 API合同。Runway未选采购/未核验目标API profile时status=guideOnly，提交按钮禁用。 |
| Google Veo/视频prompt guide（比较） | 主体/动作/场景/构图/运镜/光色用于语义编译参考；negative写法、首尾帧/音频/时长由具体API型号另查，不从指南词汇推定支持。status=guideOnly，不声称当前Google所有模型支持同一参数。 |
| deepseek-v4-pro / deepseek-flash / Qwen / Whisper | 分别是文本规划、图像分析、本地文本提案、ASR能力，均不是视频像素生成器；Flash多帧图像输入不等于原生时序视频。模态不支持返回MODEL_MODALITY_MISMATCH；本地能力不足只给人工/已授权云选项，不自动换provider上传。 |
