## 8F · Film/Craft Skill Library：知识资产、受审编译器与渲染注册表统一

FilmSkillAsset是既有Harness SkillPackage的一种内容类型，不另造一个能执行任意脚本的“电影Agent插件系统”。技能包含知识、参数与白名单步骤；SkillCompiler负责把它变成ShotDesign、现有Command提案或既有DAG任务。EffectRegistry负责可执行像素/音频算子，知识条目本身没有渲染能力。

```text
// packages/studio_craft/{skill_repository,retriever,compiler,registry_bridge}.dart
FilmSkillRepository.importPack(token,namespace,signaturePolicy)->SkillImportPreview
FilmSkillRetriever.search({emotion,rhythm,genre,purpose,capabilities},budget)->SkillRef[]
CraftSkillCompiler.compile(skillRef,params,scope,readSet,capabilities,grant)->CraftProposal
CraftProposal {id,skillSnapshotHash,compilerVersion,
 shotDesignPatchGroups:PatchGroup[],editPatchGroups:PatchGroup[],
 workflowDagRef:null|Hash,softWarnings:string[],unsupportedFields:string[],
 requiredApprovals:string[],readSet,writeSet,previewRecipeRef:null|Hash}
SkillUseSnapshot {skillId,version,contentHash,parameterBindingsHash,compilerVersion,
 capabilitySnapshotHash,compiledRecipeHash,requiredRendererFeatures:string[]}
RegistryBridge.resolve(pluginType,pluginVersion,backend)->OperatorDescriptor|Unsupported
OperatorDescriptor {id,version,inputPorts,parameterSchemaHash,resourceCollectorId,
 cpuReferenceHash,gpuShaderHashes,backendFixturesHash,enabled:bool,requiredFeatures}
// SkillPackage.manifest保留requiredTools/inputSchema/outputSchema/testFixtures；
// contentType=filmCraft，payload=FilmSkillAsset，模型请求只拿相关展开片段。
// EffectRegistry仍是唯一算子目录；新技能不能注册未经审核的Shader/FFmpeg滤镜字符串。
Project.extensions["studio.craft-library.v1"] = {
 schemaVersion:"1.0.0", uses:SkillUseSnapshot[], portableSkillHashes:Hash[]
}
// 实际已编译的clip/effect/transition在核心工程，换机器不需要再调用LLM重编。
// 没有render新语义的skill元数据为advisory；用到新operator必须声明requiredFeatures。
// 旧schemaVersion=2.0.0不增加Transition.kind枚举，不把luma写进dissolve字段冒充支持。
```

| 资产族/可拷贝条目规范 | 编译、适用反例与审片 |
| --- | --- |
| camera_craft / lighting_craft | 条目覆盖推/拉/摇/移/跟/升降、dolly zoom、手持纪实、正反打覆盖、长镜调度、动机光/反差照明。每个条目必含narrativeUses、counterExamples、参数槽/单位/范围/default、providerMapping、reviewChecks和来源。相同名字不是统一物理API；Wan的焦段/运镜仍是promptSuggestion，要求硬物理控制但无能力→CAPABILITY_UNSATISFIED。 |
| 示例camera.dollyZoom@1.0.0 | 用途=人物认知突变/空间不安，反例=平静产品证明镜头、不稳定人脸特写。槽位direction(backDolly_zoomIn或forward_zoomOut)、duration、framing、subjectDistance/focalIntent；固定主体比例近似f/z不变，精确薄透镜需统一单位与机位几何，不向2D视频模型承诺数学控制。编译成“相机后移同时收紧视角，主体占画面比例尽量稳定，背景空间感变化”的单镜建议，SOFT_CAMERA_CONTROL；审片查主体尺寸漂移、脸部变形、相机和变焦是否反向。后期单纯数字变焦不能冒充真实dolly zoom。 |
| 示例coverage.reverseShot@1.0.0 / lighting.motivatedContrast@1 | 工作流前置轴线与人物眼线；master/reverse/reaction分镜分别生成，长镜调度若复杂移动超profile能力提拆镜而非承诺一条prompt。布光技能传光源动机/方向/软硬、明暗与色彩对比服务于剧情；精确曝光比/色温仅作意图，最终按可用colorBasic与人工审片，不假称P1有全套电影调色台。 |
| editing_craft：J/L / 音画错位切 | 参数J/L、offsetQ、left/right AV Clip与音轨；前置解link许可/音轨可写、handles、源时码与碰撞检查。J=下一音提前，编译既有unlink＋trim/move batch，选中source音头余量不足拒绝，锁音轨不改。inverse引用既有before snapshot，一次Undo恢复全部，不把J/L塞进视频模型prompt。 |
| editing_craft / workflow_craft：match cut | 需要out/in FrameAnchor、主体位置/轮廓或运动方向匹配意图，适用于形状/动作呼应，不用于必须保证真实因果的教程证明。工作流依次提议前镜出动作→后镜构图/参考→双端QC→cut点→声音衔接；可复用旧take则不新收费，新生成必须再次审批。匹配只做建议/指标，不能保证像素连续或强行翻转文字商标；最终编译hard cut或用户选定已支持转场。 |
| transition_craft：dissolve / flash white | dissolve使用既有Transition(kind=dissolve)线性光节点并验证两端handles；audioEqualPower仅用于音频交叉。flash white无需新枚举：自有白色RGBA图片Asset在上层短Clip，opacity 0→1→0关键帧，覆盖中心硬切；attach/insert/setEffect等白名单命令同batch，一次可撤。时间/亮度/频闪风险先预览，不默认给敏感用户快速高频闪烁。 |
| transition_craft：参数化luma/遮罩（注册后开放） | 定义受审plugin studio.fx/lumaWipe 或 studio.fx/maskWipe，pluginVersion=1.0.0；未通过CPU/GPU/Web golden、资源collector与capability探测则enabled=false，返回UNSUPPORTED_EDIT_TECHNIQUE，不因技能存在就算已支持。核心Effect.type合法扩展形式，owner=sequence，参数指向同轨相邻left/right Clip、cut/before/after、mask与softness；按Effect.owner聚合，不能给封闭Sequence新增effectIds。 |

```text
// native/studio_media/registry/{luma_wipe,mask_wipe}：本轮设计，尚未实现插件。
LumaWipeParams {sequenceId,trackId,leftClipId,rightClipId,cut:Q,before:Q,after:Q,
 maskMode:incomingLuma|assetLuma|assetAlpha,maskAssetRef:null|EntityRef,
 softness:number[0.001..0.5],invert:bool}
// 参数schema闭合；before+after>0，cut等于相邻clip边界；两侧同track无gap。
// 输入source按既有Transition handles公式在[cut-before,cut+after)虚采样，
// 不修改普通Clip区间来制造重叠；超源HANDLE_UNAVAILABLE，P1不假装有freeze fallback。
p=clamp((t-(cut-before))/(before+after),0,1)
m = maskMode==incomingLuma ? dot(B.linearRGB,rec709LumaCoefficients) : sampledMaskData
if invert: m=1-m
threshold=1+softness-p*(1+2*softness)
w=smoothstep(threshold-softness,threshold+softness,clamp(m,0,1))
output=(1-w)*A + w*B   // linear-rec709 premultiplied RGBA，包括alpha
// p=0全A，p=1全B；mask纹理按data而非随意ICC颜色解释。
// assetAlpha为有alpha遮罩；assetLuma是有权使用的灰度asset，不是任意文件路径。
// P1外部mask只接受静态image，归一方向/UV、bilinear+clampToEdge、显式data采样；
// 视频matte需另有timeMap合同，当前拒绝MASK_MEDIA_UNSUPPORTED，不猜它的播放速度。
// 同轨同窗口若已有core Transition或另一pair operator，返回TRANSITION_WINDOW_CONFLICT，
// 用户可接受含removeTransition的替换batch，不能重复混合这对源。
// CPU参考与Metal/GLSL/HLSL、Web独立WGSL实现需同fixture容差通过，不声称二进制通用。
// RenderGraphCompiler在这个track的窗口用TransitionSampleNode替代原普通二选一采样，
// 然后和其它轨合成，避免同一对源又混一次。音频不随luma自动淡入淡出。
// Registry resource collector枚举mask/dependent refs参与pin/GC；seek/cancel沿用7A FrameLease。
// 即便Effect owner=sequence，也计算affectedTrack/Clip targets并检查其锁，禁绕锁影响片段。
// 编译setEffect(proposed plugin)之前检查registry enabled+backendFeature；
// requiredFeatures += studio.craft.luma-wipe.v1；不支持端只读/阻render，不能悄悄退成dissolve。

// 统一技能安全与召回算法
retrieve(query):
  ACL-filter namespace/library grants -> FTS(tags/title/use/counterexample)
  capability/rights过滤 -> 按用途+情绪+节奏排序 -> top3、tokenizer预算≤1200(初始可调)
  模型只接知识摘要/必要参数；完整白名单步骤由确定性compiler按contentHash加载。
import(pack):
  路径/大小/hash/schema/签名信任链/来源许可校验 -> 展示权限差异 -> 用户确认
  unsigned允许作为untrusted知识预览；执行仍须确认且不能新增工具权限
  拒shell/动态代码/远程$ref/任意网络URL工具/加载Shader源码/安装模型步骤
  DAG≤16步/禁止循环与递归扩张；参数numeric范围、枚举、EntityRef和scope逐项验证
execute(compiled):
  requiredTools ⊆ installedAllowlist ∩ sessionGrant ∩ branchScope
  每步仍过ToolRuntime＋Budget/Upload/License/Portrait gates；不把skill signature当用户审批
  先输出preview/diff，用户接受才走CommandCoordinator revision CAS
// 相机技能可只产生软prompt；剪辑技能只产生受审commands；复合技能复用现有DAG Scheduler。
// 项目保存skillId/version/contentHash/params/recipe，升级技能须显式diff与再编译，
// 不能因全局知识库更新重写已经手调的时间线。
```

合成串联例：@岚(pin1、绿衣Look)＋workflow.motionMatch@1，导演Agent取三条相关技能而非整库，视觉Agent检查两端参考帧；用户接受“向右出画→向右进入下一镜”的计划，Compiler给Wan软运动prompt并显示SOFT_CAMERA_CONTROL。已有镜头足够则只提MatchCut与J音头0.4秒batch；音头只有0.2秒时拒绝并让用户选独立授权foley或缩短J，不偷补源。随后加luma wipe若未注册，UI明确阻断该技巧，可另选hard cut/dissolve；不改已锁字幕或音乐手调gain。

### Signed import verification supplement

[Signed Film/Craft import v1](s8f-signed-import-v1.md) completes the bounded DSSE/Ed25519 envelope, exact authenticated bytes, trusted direct-key policy and preview binding under t155u. This plan does not make ExternalSkillRequest.signed cryptographic evidence, change existing privilege gates, or implement verified import.

[Web import composition v1](s8f-signed-import-web-v1.md) specifies the browser-only prerequisite and independent tests; Increment 3.47 does not implement or qualify that port.

[App selection / preview-consent composition v1](s8f-signed-import-app-v1.md) completes the explicit App-owned source/read/presentation/one-use-consent planning prerequisite. Increment 3.49 is plan only, not UI/picker qualification or installation/tool approval.
