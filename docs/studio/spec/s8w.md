## 8W · 策略接口、依赖重建、时间与全成本

```text
// studio_generation/shot_strategy_planner.dart
// artifact namespace urn:studio:shot-execution:1.0.0；Project2.0.0闭合根Schema不变。
ShotExecutionPlan {
 schemaVersion:"1.0.0", id:Id, version:UInt64String, shotId:Id, projectRevision:UInt64String,
 intentVersion:UInt64String, strategy:still|pan_zoom_2d|layered_2_5d|i2v_micro|full_motion,
 inputRefs:VersionedHashRef[], characterPins:VersionedHashRef[], craftPins:VersionedHashRef[],
 hardConstraints:Constraint[], softPreferences:Constraint[], explorationBounds:Bound[],
 layerBundleRef:null|VersionedHashRef, dialogueMeasurementRef:null|VersionedHashRef,
 target:{startFrame:Int64String,durationFrames:PositiveInt64String,rate:{num:PositiveInt64String,den:PositiveInt64String}},
 nativeCapabilityRef:null|VersionedHashRef, rendererPins:VersionedHashRef[],
 executionTarget:phoneLocal|ownGpu|authorizedCloud, fallbackProposals:StrategyProposal[],
 animaticRef:VersionedHashRef, animaticApprovalRef:null|Id,
 licenseDecisionRef:Id, quoteRef:null|Id, approvalBindingRef:null|Id,
 // licenseDecisionRef保留事实；执行assessment由1C sidecar引用，不以其legacy block直接禁调度。
 readSet:VersionedRef[], writeScope:FieldPath[], manualLockRefs:Id[],
 maxAttempts:PositiveInt, maxSpend:Money, dependencyRefs:VersionedHashRef[]
}
// 所有字段required，仅显式null可空；additionalProperties:false；Id非空、hash=SHA256。
// 时间/版本64位十进制字符串；有理数/溢出沿已有核心，不用JS Number保存时间。
// maxAttempts 1..8是本产品默认安全上限非模型能力；项目可更严格。
// Money复用精确decimal+currency，未明汇率不能跨币种相加。
// VersionedHashRef沿既有namespace/id/version/hash；VersionedRef和FieldPath沿Harness readSet/writeScope。
// StrategyProposal{strategy:同五种enum,reasonCode:非空string,requiredRefs:VersionedHashRef[],requiresApproval:true}
// Bound{field:白名单FieldPath,min:null|finiteNumber,max:null|finiteNumber,allowedValues:Scalar[]}
// Scalar仅null/bool/finiteNumber/string；禁止可执行代码；至少有min/max/allowedValues之一，min<=max。
// Constraint{id:Id,field:白名单FieldPath,relation:eq|in|lte|gte|present,expected:Scalar|Scalar[],
// evidenceRefs:VersionedHashRef[],scope:shot|sequence|project,verification:deterministic|model|human}
// 同上全部required/additionalProperties:false，不能经自由field路径逃逸writeScope/权限。
// 约束值沿既有类型化artifact；结构校验与引用/时间/rights语义校验分开。
ShotStrategyPlanner.plan(ShotSpec,ProjectSnapshot,CapabilitySnapshot,Policy):Proposal<PlanGraphDelta>
StrategyCompiler.compile(plan):existing PlanGraph // 不创建第二套Run/Job状态机
AnimaticBuilder.build(plan,voiceRefs):Artifact // 共享编辑图，准确sample时长
ApprovalBinder.bind(planHash,animaticHash,quoteHash,rightsEpoch,revision,locks):existing ApprovalBinding
RepairPlanner.invalidate(changedRefs):DependencyClosure // 字段级依赖+锁，只产proposal
// 现有Step/Job派生状态：draft→validated→waitingApproval→ready→running→QA→candidateReady；
// blocked/needsInput/failed以及cancel/late/quarantine复用10B—10D，不另双写状态。
// 错误：STRATEGY_PREREQUISITE_MISSING / DEVICE_NOT_VALIDATED / FRAME_CONSTRAINT_UNSUPPORTED /
// ANIMATIC_APPROVAL_STALE / DIALOGUE_OVERFLOW / BUDGET_EXCEEDED / FIELD_LOCKED / REVISION_CONFLICT。
// 保存恢复沿5B—5E引用闭包：plan/输入/能力/许可快照；不能恢复已删除正文/被取代意图。
// 新dispatch重检当前许可/rights与预算，历史审批不能借归档复活。

// 原生帧率→交付帧率：按源presentation PTS，不改fps元数据偷变速。
// 输出帧k：outTime=(k-startFrame)*rate.den/rate.num；sourceTime=sourceIn+retime(outTime)。
// hold取pts[i]<=sourceTime最大的i；不以decode-order/帧号索引VFR。
// blend/optical flow须另明确启用注册策略；短源不足报错或提议持帧，不静默拉长动作。
// 24fps×15秒=360帧；16fps四秒源采样96帧，时长仍四秒，VFR同理。
// 生成原生fps/frameCount/尺寸模数/离散时长按capability pin约束，不能编造任意3秒请求。
// 请求合法原生长度后经批准trim；probe PTS后映射并保存源/音频sample范围。
```

| 项目 | 合同 |
| --- | --- |
| 估算 | 覆盖全部候选/有界retry、GPU计费秒/请求费、冷启/保温、LLM/TTS/分析、存储/出口、审核、模型许可、平台支付、退款/售后、固定费摊销。unknown列区间/需报价，不当0。自有GPU仍有电/折旧/排队/失败成本；Serverless不等于零固定成本。 |
| 上限 | reservation冻结单币种上限；quote已含冷启不再重复计。重试前查余额，submit_unknown先对账不重发；费用/尝试/墙钟/资源任一耗尽即停。取消仅阻未提交，已提交按receipt结算。无真实价格/速度承诺。 |
| 指标 | usableShotRate=通过明确定义QA且用户接受的候选/已完成候选。分角色漂移/指令/商品事实/叙事/视听质量记录模型、确定性与人工结论及unknown。另记每接受镜头尝试数、返工比例、端到端p50/p95、每成片实际全成本；无数据不承诺节省50%或2秒出图/20秒出片。 |
| 端侧 | 手机内存/热/后台按实际设备验证；不设全手机4GB上限、不称本地视频物理不可能。研究性小分辨率演示不等于商业短剧已支持。用户自有GPU不等于必须云，跨设备/云上传需明确授权，无静默云降级。 |
| 一致性 | CFG通常增强prompt引导，不是通用创造力开关；API可能不暴露或固定。seed/参考图/IPAdapter/LoRA/首尾帧均依赖底模/版本/模式，不能保证绝对身份/空间/动作一致；首尾帧仅真实capability支持时可用，LoRA非必选。 |
