## 8D · AI音乐与音效：三个模型Profile、许可事实、风险放行与可编辑入轨

本轮把原先generated音频策略的空位落到实际模块：默认商业部署采用ACE-Step 1.5自托管服务；Stable Audio Open Small作为端侧短音效/Loop的待验配置；YuE2接入同一Provider合同，但商业托管许可事实与执行分离，缺许可按1C默认allow_with_warning。开源代码许可、权重许可、推理依赖、输入音乐/歌词/肖像声线权利和生成输出风险分别检查；开源不等于推理零成本，也不等于输出绝不侵权。

| 官方核验与固定Profile | 实际能力与编译限制 | 许可/部署决定 |
| --- | --- | --- |
| ACE-Step 1.5：ACE-Step/acestep-v15-turbo；编辑/提取用acestep-v15-base，LM独立固定版本 | 官方API /release_task→task_id→/query_result(status0/1/2)；10..600秒，BPM30..300，key_scale、time_signature；task_type=text2music/cover/repaint/lego/extract/complete。Turbo不等于Base全部能力：模型卡中extract/lego/complete仅Base，不能拿Turbo广告表概括所有变体。 | 官方代码MIT、模型卡MIT并允许商业输出。作为商业云端主选；先固定DiT/LM/VAE/tokenizer/包依赖hash再上线。README低于4GB为特定offload说法，XL4B另需≥12GB；不把这些或A100速度当本App实测。 |
| Stable Audio Open Small：stabilityai/stable-audio-open-small | 官方发布称341M、Arm CPU优化；模型卡为English text→≤11秒44.1kHz stereo，T5+DiT+autoencoder。适合foley、环境、鼓Loop，不擅长真实人声/完整歌。seconds_total为长度condition，BPM/调性写prompt并回听测量；不支持假想的歌词精确同步/原生分轨/任意局部重绘API。 | 社区许可，不是MIT/Apache。商业使用要求登记及收入门槛/关联企业规则，另有Notice、Powered by Stability AI、AUP等义务。选择已获合法访问的LiteRT/TFLite Arm包，混合int8/fp32与峰值RAM另测；未登记/许可证不明记风险但不因该缺口阻下载/启用，不注册任何账户。本轮raw模型卡401后改读同一公开模型页面与官方LICENSE，未绕过登录。 |
| YuE2：m-a-p/YuE2-3B + YuE2-Vae，模型/decoder revision分别冻结 | 官方分阶段plan→generate_semantic→synthesize→decode，48k stereo；cot=full生成旋律+和弦ABC，melody只旋律，off无计划。修改ABC后是整段新录音，不保证区外波形不变。full/melody才接受abc；原生Vocal/Ins两声部是符号谱，不是可独立下载的音频stem！ | 代码/技能/文档Apache-2.0，权重及VAE为CC-BY-NC4.0＋2026-09-16个人创作者附加许可。个人创作者可变现输出；这不授权公司商用权重或商业App托管权重。缺书面商业授权保留受限事实，按1C默认允许执行并警告，不等于获得托管权。标准起点官方建议24GB BF16 NVIDIA；其他硬件路径为实验，不承诺手机。 |

```text
// packages/studio_audio_generation/{contracts,license_gate,music_compiler,candidate_store}.dart
MusicGenerationProvider.describe(profileRef)->MusicCapabilitySnapshot
MusicGenerationProvider.quote(compiledPlan)->Quote|QuoteUnavailable
MusicGenerationProvider.submit(ApprovedMusicRequest,idempotencyKey,cancel)->Submission
MusicGenerationProvider.poll(jobRef,cursor)->AudioJobEvent[]
MusicGenerationProvider.cancel(jobRef,reason)->CancelReceipt
MusicGenerationProvider.fetchOutputs(jobRef,downloadGrant)->AudioOutputManifest
// 同一Port的本地实现也返回JobRef/事件；不要求端侧先启动HTTP服务器。
MusicModelProfile {id,version,providerId,modelIds:ModelIdentity[],
 runtime:aceService|yuePythonWorker|liteRtLocal,platforms:string[],
 capabilityHash,licensePolicyRef,resourceProfileRef,parameterAllowlist:string[],
 minDuration:Q|null,maxDuration:Q|null,durationControl:conditioning|scoreAndTokens|none,
 tasks:string[],stemSupport:nativeVerified|separateModel|none,
 waveformEdit:approximateInpaint|fullRegenerate|none,
 cancelSupport:gatewayOnly|cooperative|remoteVerified,
 localeSupport:string[],outputRates:int[],dataPolicyRef}
ModelIdentity {modelId,revision,weightsHash:null|Hash,codeCommit,configHash,
 tokenizerHash:null|Hash,decoderRevision:null|string,licenseTermsHash}
// MusicSpec完整JSON Schema见8G；未知字段拒绝。BPM/拍号是生成条件，不是波形节拍保证。
MusicPlan {id,specRef,compiledRequestHash,providerProfileRef,licenseDecisionRef,
 inputAssetRefs:EntityRef[],uploadPlanHash,quoteHash:null|Hash,
 generationUnits:{seconds:Q,candidates:int,stages:string[]},
 approvalBinding:null|Hash,baseProjectRevision:I64,dependencies:DependencyRef[]}
AudioCandidate {id,planId,runId,parentCandidateId:null|Id,
 state:processing|ready|rejected|selected|quarantined,
 mixAssetRef:EntityRef,stems:StemAsset[],scoreABCRef:null|Hash,
 generationRecordRef,probeRef,qualityReportRef:null|Hash,
 aiDisclosure:{generated:true,modelIdentities:ModelIdentity[],userEdited:bool,
              licenseDecisionRef,inputRightsRefs:Id[]},createdAt}
StemAsset {id,role:vocals|accompaniment|drums|bass|other,assetRef:EntityRef,
 sourceMixRef:EntityRef,origin:verifiedNative|estimatedSeparation,
 sourceSampleOrigin:I64,alignmentMapRef:null|Hash,
 phaseAligned:bool,bleedWarnings:string[],separationRecordRef:null|Id}
// 具体实现：AceMusicProvider / YuEWorkerProvider / StableSmallLocalProvider实现同一Port。
// 每个mix/stem是既有Asset(kind=audio)+独立Blob，不增加Project.Asset.kind。
// QuoteLine按generatedAudioSeconds/processedAudioSeconds/gpuMilliseconds明确单位；
// stems二次分离/ABC转录另列处理量和费用，不能把“生成一次”包装成后续免费无限执行。
// Song score ABC不是执行脚本；不从ABC里的URL加载字体、include或插件。
StemSeparationPort.plan(mixRef,requestedRoles,capability,rights)->Plan|Unsupported
// YuE2没有已核验的native音频分轨，走已配置且许可合格的ACE base extract等分离Port。
// 未配置/提取角色不支持则STEM_CAPABILITY_UNAVAILABLE，不能伪称Vocal/Ins就是两轨音频。
// 分离结果标estimated，可能串音/相位差；不承诺重新相加严格等于原混音。
```

| 编译器与工作方式 | 可编码映射/异常 |
| --- | --- |
| ACE adapter | MusicSpec.description→prompt，lyrics正文→lyrics，voiceMode instrumental用明确器乐描述+空歌词；bpm→bpm（ACE要求整数，120.5须BPM_INTEGER_REQUIRED或用户明确同意取整的新计划），key→key_scale。meter只接受官方2/4、3/4、4/4、6/8→time_signature字符串2/3/4/6，其余CAPABILITY_UNSATISFIED，不丢拍号。duration Q转受检10..600秒数，输出偏差按probe处理。repaint映射source音频、repainting_start/end与chunk_mask_mode；不承诺mask外绝对波形不变。extract先检查实际加载Base profile及track指令能力。强参数以官方API为准，不能把Base-only guidance传Turbo。 |
| YuE2 score/cover adapter | style承接语言/风格/乐器/人声/BPM意图，lyrics含Verse/Chorus结构；不把LRC时间标签当专用对齐API。先plan保存ABC供用户改谱/和弦，再按批准的scoreHash生成；不修改已保存SymbolicPlan文件原地复用。cover可接用户已授权ABC；录音→乐谱需另选SheetSage2/MERT2依赖并核许可/算力，P1未安装时明确TRANSCRIBER_UNAVAILABLE。melody模式先解析ABC移除和弦、保留所选声部/休止；不靠cot自动删和弦。用户改谱后完整新candidate，不用局部重绘UI谎称区外保真。 |
| 纯音乐与声线 | YuE2空歌词+官方器乐workflow可将Vocal旋律移至Ins后渲染，仍需验人声泄漏。两ABC声部不代表每件乐器独立控制。其公开请求没有参考speaker/音素/per-section歌手ID字段；Character.voice不能自动变成YuE2声音克隆。SA Small不做真实唱词；精确歌词字幕由ASR/对齐后人工校准，LRC只是用户期望时码。 |
| Stable local adapter | description翻译成获用户认可的英文prompt；BPM/key/meter只作软建议；seconds_total在11秒内，8步/CFG1/pingpong来自模型卡示例而非所有设备最佳值。真实长度以probe为准，Loop只输出候选并测接缝，不能保证sample周期无缝。44.1k Float32→FFmpeg swresample→48k Float32工作副本，保原输出与重采样映射；不照抄示例先强制int16削失精度。 |
| 统一任务生命周期 | draft→validated→licenseAssessed/执行策略已评估→quoted/waitingApproval→queued→submitted/running→fetching→ready，或blocked/failed/cancelRequested/canceled/quarantined。付款/上传批准继承10A精确binding，新增model/decoder/license terms及角色voice权利hash；输入/人物声音同意/上传预算/revision实际变化使批准失效；仅商业许可资料变化按1C刷新warning或签同范围rebase receipt。ACE官方API未核验cancel接口，自有gateway只保证未发队列取消及自管worker协作终止；不虚构上游/cancel。YuE progress回调仅代表提交的工作，GPU同步结束后再释放。 |
| 生产网关/失败恢复 | ACE文档是自托管API不是可直接购买的公共SaaS；自有AudioGateway负责鉴权/租户、报价、outbox幂等和隔离worker。Client只传AssetToken，不传服务器任意文件路径；返回/v1/audio?path由网关解析并代理，禁止原样变成任意文件下载。提交unknown不重POST，先按幂等receipt/job对账；429可有界退避，OOM释放资源后排队/另提较短计划，不自动转付费服务。输出先限制大小/时长、校验hash、probe及finite samples再入CAS。取消后晚到结果隔离，结算按实际receipt，不承诺退款。 |

```text
// LicenseComplianceGate仅评估事实；1C ProjectExecutionPolicy决定项目执行，非许可门禁仍独立。
LicenseEvaluationContext {modelIdentities,actorLicenseeId,
 actorCapacity:individualCreator|company|institution,
 deployment:commercialHosted|personalLocal|personalBYOK|integratedEndUser,
 operatorControlsWeights:bool,publisherLicenseRef:null|Id,
 use:generate|train|redistributeWeights|exportOutput,
 jurisdiction,now,termsSnapshotHashes,inputRightsRefs,entitlementRefs}
LicenseEvidenceRecord {id,licenseeId,modelScopeHashes:Hash[],allowedDeployments:string[],
 allowedUses:string[],notBefore,expiresAt:null|Timestamp,revoked:bool,
 evidenceBlobRef,verificationStatus:pending|verified|rejected,reviewerRef}
LicenseDecision {id,state:allow|block|needsReview,reasonCodes:string[],
 obligationIds:Id[],termsHashes:Hash[],evidenceRefs:Id[],validUntil:null|Timestamp,
 contextHash,issuedAt,revocationEpoch}
LicenseComplianceGate.assessFacts(ctx, commercialUseContext:CommercialUseContext)->LicenseDecision
// 上述state保留legacy事实语义，block/needsReview不直接决定执行；缺资料记unknown/missing。
// weights/code/decoder/tokenizer/runtime逐项记录事实，输入音乐/歌词/声线权利独立验证。
// ACE MIT及NOTICE义务如实展示；无不侵权保证。
// SA登记、Core Model/聚合营收门槛、NOTICE/Powered by/AUP为事实条件；
// 未登记/收入未知或跨门槛记风险，默认allow_with_warning，不捏造登记或企业许可。
// YuE2个人创作者商业输出例外保留；商业App托管缺授权记录restricted/missing，
// YUE_COMMERCIAL_LICENSE_REQUIRED只作warning，默认风险放行；不伪造书面grant。
// BYOK不改变许可事实，但也不以缺商业许可硬阻断。代码许可不等于权重商业授予。
// 法定/合同义务不因执行策略消失；地区/用途/失效/撤销商业grant都保留证据与提示。
// 仅商业许可变化刷新事实/审计，不取消现有job；portrait/voice/privacy撤销仍按原硬门禁。
// 下载安装/submit/export分别记录1C执行assessment，预算/上传/安全/能力等仍独立通过。
// 这不是法律意见，也不签发任何真实授权凭证。
```

| BeatGrid / Ducking / 入轨 | 公式与保护规则 |
| --- | --- |
| BeatAnalyzer native离线 | C++ worker用48k mono分析副本，2048 Hann、hop512的正谱通量及onset，30..300BPM滞后自相关提出tempo/phase；半拍/倍拍、rubato、无鼓点返回uncertain。BeatGrid{assetRef,sourceVersion,analysisProfileHash,sourceSampleRate,tempoUnitInQuarterNotes,events[{sample:I64,beatIndex,barIndex,confidence:null\|number,manual}],meter,coverage,version}；算法和模型建议不等于实测节拍。用户可手动tap/拖点，锁manual事件，重分析只提diff。 |
| 精确节拍与视频切点 | 恒定BPM的第n拍sample=roundEven(origin+n×60×Fs/BPM)，每拍从绝对式算，不能累加round(Fs×60/BPM)。120BPM/48k→0/24000/48000/72000，30fps每拍15帧。BPM单位须说明quarter/dottedQuarter等，bar时长按拍号与tempoUnit换算，6/8不默认等于6个四分音符。映射sequence时经过Clip sourceRange/TimeMap反函数，视频切点再落帧；音乐仍保原sample，不为吸附偷偷重定时音频。119BPM首拍60/119秒→30fps的0.5秒，UI显示4.2ms误差；锁定切点只给建议。 |
| DuckingPlanner | 从获授权对白/VO的有效区间生成DuckingProposal，不识别说话人身份；示例speech[s,e)：点(s−0.20,0dB),(s−0.05,−9dB),(e,−9dB),(e+0.30,0dB)，重叠自动envelope取更低值，端点裁至clip范围。先把sequence speech时刻转为music Clip局部timeline时间再建gain Effect关键帧，原手工gain点一字不改；手改保护区默认跳过，锁轨/锁音量返回TRACK_LOCKED/MANUAL_LOCKED，不用新增Effect绕锁。可预览允许选区另加ducking后才接受；总增益为原gain链与autoDuck相乘，不把-9dB写成原关键帧绝对值。 |
| 入库→NLE→交付 | AudioCandidate ready后用户选mix或stems其一为监听主路，避免同时叠加mix+全部stems翻倍。attachArtifacts把音频、Rights、GenerationRecord与相关meta bundle原子登记；insert在独立audio track，bus=music/foley；lyrics字幕与BeatGrid/ducking为独立提案，不自动覆盖已有VO/字幕。核心GenerationRecord沿用templateId/prompt/参数/权利/输出AssetRefs，新增音乐细节放版本化extension。AI声明模型/许可/来源与用户编辑记录随可移植manifest，包中不带服务凭据。 |
| 离线与跨端复用 | Dart负责MusicSpec/计划/许可/预算/会话；Python自管服务worker跑ACE/YuE，端侧C++/JNI/ObjC++ LiteRT adapter跑已受测SA；实时混音/淡入淡出仍在共享C++内核，Dart不在audio callback分配。iOS/Android先验证runtime、后台/热/峰值RAM；桌面可选自己的worker；Web不直接加载移动FFI/TFLite二进制，默认批准的网关或仅播放/手动音轨。未装模型/算力不足明确MODEL_UNAVAILABLE；不符商业许可仅warning按1C继续，不静默云上传。 |

合成操作例：15秒广告选择120BPM、4/4、C major器乐，MusicSpec请求ACE生成18秒含尾部余量、候选2个，报价单位36生成秒而非成片15秒。用户批准文本与可选参考音频上传→AudioCandidates→选take裁[0,15)→BeatGrid建议0.5秒网格→仅对未锁切点提剪辑diff。用户手调第4秒音量后，DuckingPlanner保留该保护区；局部音乐重绘只产新候选，当前音频不被后台替换。选YuE2显示商业许可风险卡并默认可继续；付款确认仍不等于拿到权重商业许可，也不代替上传/肖像声音同意。
