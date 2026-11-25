## 8A · 多模态摄取：保留来源与证据，再共用文本投影

文本、图片、视频、文本文件共用的是“证据记录→可授权检索→文本投影→ContextCompiler”，不是把所有东西扔进一个聊天字符串。视频字幕不等于画面，OCR不等于理解，若没有时序视觉能力就不能声称看懂动作。所有附件、网页摘录、OCR、ASR和模型分析均为untrusted data；其中出现的上传、删除、运行代码等句子不构成工具权限。

| 入口与P1边界 | 实际处理及上限 | 错误/降级，非静默成功 |
| --- | --- | --- |
| 文本/文本文件 | 单次手输≤64KiB UTF8；TXT/MD/CSV/JSON/SRT/VTT≤16MiB。UTF8严格解码、UTF8 BOM、带BOM的UTF16LE/BE；GB18030等须用户显式选编码再解码。正文分段目标1200 Unicode码点、重叠120，上限2000；更长按页游标读取，不把整个文件塞上下文。 | 拒绝非法字节ENCODING_REQUIRED，不以替换字符偷偷改变品牌词。CSV当字符串不运行公式，Markdown禁活动HTML，JSON拒重复键/深度>64。SRT/VTT只形成带源时码的建议，不自动改字幕轨。DOC/DOCX/Pages/压缩包P1不解析，显示UNSUPPORTED_DOCUMENT，用户可主动转PDF/TXT。 |
| PDF | ≤50MiB、≤500页，先目录/页数；默认仅选中页或前10页。先取文本层，乱码/无文本的页可显式OCR，分页10页/任务；单页栅格≤8MP。原生采用隔离PDFium适配，Web采用pdf.js worker，固定版本和第三方清单。 | 加密PDF报ENCRYPTED_DOCUMENT，不要求云解密；不执行PDF JS、附件或外链。文本层缺字与OCR读错分别标注，分页覆盖不完整不能总结“全书没有”。PDFium许可证并非一句BSD即可概括，当前LICENSE与第三方依赖须逐项审；不默认嵌入GPL Poppler或AGPL MuPDF。 |
| 图片 | P1 JPEG/PNG/WebP静态，≤20MiB、≤40MP；先解析尺寸防解压炸弹。EXIF方向归一，保留原图与像素映射。OCR独立于VLM；默认语义图最长边1600，文字小区域可点选深读。 | HEIC/AVIF/动画图须本端decoder能力通过后开放；否则UNSUPPORTED_IMAGE_PROFILE，不假装首帧等于动画。HDR分析生成标明tone-map版本的SDR副本，不更改原件。OCR缺语言包/本地模型未装→能力不可用，可选仅文本/手动标注；不能自动上传。 |
| 视频/音频 | 视频引用可到2GiB/2小时；这是导入上限而非一次分析量。P1按现有MediaPort可解码profiles；默认分析选区或前60秒，每次区间≤10分钟。低清逐帧场景候选扫描；常规1fps+切点邻帧，初始最多96帧。音频16k mono，本地ASR窗口30s、步长29s。 | 不支持codec先按第7节本地归一/拒绝；无声轨明确noAudio，不捏造转写。帧预算耗尽记录未覆盖区间并给“深读此段”；不把96帧称为完整运动理解。长媒体分区任务各自可取消。说话人默认null，Whisper base不是diarization或身份识别。 |

```text
// packages/studio_ingest/contracts.dart；全部为设计合同，不是已实现库。
// 新工作区记录schemaVersion=1.0.0；所有列出的持久化字段必需，可空处显式null；
// 禁未知字段；构造器填默认值后再验证，反序列化不自动补默认。
// ID是不含路径/凭据的opaque字符串；I64沿用十进制字符串，Q沿用项目有理数。
// 默认限制：ID≤128字符、单行≤1024、描述≤16384、数组≤1024、对象深度≤32；
// 单独给出更严格限制时优先。缺必填/未知字段拒绝，不截断；null仅在显式标注处。
type BodyRef = Id; // input_bodies里的受控引用，不是路径/URL/正文
ProfileRef {id,version:I64}
SourceEpoch {sourceId,grantId,epoch:I64}
SourceDependency {sourceId,sourceVersion:I64,blobHash:Hash,
  selector:EvidenceLocator,grantId,sourceUseEpoch:I64}
EvidenceRef {artifactId,artifactVersion:I64,evidenceUnitId}
IngestError/AnalysisError {code,retryable:bool,messageKey,detailsRef:null|BodyRef}
// 引用合法、权限、range覆盖、id唯一、bbox几何、hash真实性另由语义Validator验证。
MessageEnvelope {schemaVersion,id,turnId,orderedParts:ContentPart[],recordVersion:I64}
ContentPart =
  TextPart {kind:"text",id,bodyRef,locale:null|string,sourceUseGrantId}
 | AttachmentPart {kind:"attachment",id,attachmentId,selection:EvidenceLocator|null,
                   userQuestionRef:null|BodyRef,sourceUseGrantId}
Attachment {schemaVersion,id,namespace,ownerProjectId,mediaKind:text|document|image|video|audio,
  assetRef:null|EntityRef,blobHash:null|Hash,sourceVersion:I64,mime:null|string,
  displayNameRef:BodyRef,sizeBytes:I64,origin:picker|paste|generated|archive,
  state:staged|probing|ready|unsupported|denied|failed|revoked|purged,
  probeRef:null|Hash,sourceUseGrantId,recordVersion:I64,error:null|IngestError}
SourceUseGrant {id,namespace,sourceId,sourceVersion,agentScopes:string[],
  permitted:(read|analyze|uploadSubset)[],providerRegionAllowlist:string[],
  expiresAt:null|Timestamp,epoch:I64,state:active|revoked}
// read/analyze/uploadSubset互不暗含；仅分析权限不等于授权第三方上传。
// uploadSubset还需精确UploadPlan和审批，单有grant不能直接上传。

AnalysisRequest {id,attachmentId,sourceVersion,selector:EvidenceLocator,
  level:probe|literal|visual|temporal,questionRef:null|BodyRef,
  extractorProfileRef,modelProfileRef:null|ProfileRef,parametersRef:Hash,
  intentSliceHash:Hash,frameBudget:uint[0..512],tokenBudget:uint[0..32768],
  sourceUseGrantId,expectedSourceUseEpoch:I64,cancelEpoch:I64}
AnalysisTask {id,requestHash,state:queued|running|waitingApproval|completed|partial|failed|canceled,
  producedArtifactRefs:Hash[],resumeCursor:null|string,error:null|AnalysisError,recordVersion:I64}
AnalysisArtifact {schemaVersion,id,namespace,kind:probe|text|ocr|asr|visual|temporal,
  inputRefs:SourceDependency[],extractor:{id,version,buildHash},
  model:null|{profileId,profileVersion,resolvedVersion:null|string,parameterHash,promptHash},
  requestHash,createdByRunId:null|Id,completeness:complete|partial,
  coverage:Coverage,claims:EvidenceUnit[],dependencies:DependencyRef[],
  permissionScopeHash,sourceUseEpochs:SourceEpoch[],artifactHash:Hash}
// artifactHash是去除自身artifactHash字段后的规范JSON hash。Artifact不可变；
// valid/stale/revoked/purged是DB中ArtifactAccessRecord状态，不覆写原blob。
EvidenceUnit {id,kind:observation|inference|userAssertion|derivedMetric,
  textRef:BodyRef,structuredValueRef:null|Hash,evidence:EvidenceLocator[],
  confidence:{score:null|number[0..1],meaning:notApplicable|engineScore|calibrated,
              calibrationRef:null|Hash},
  limitations:string[],dependencySelectors:DependencyRef[]}
EvidenceLocator =
  TextSpan {kind:"text",sourceId,version,startByte:I64,endByte:I64}
 | PageRegion {kind:"page",sourceId,version,page:uint[1..500],
               bbox:null|[x,y,w,h],textSpan:null|[I64,I64]}
 | ImageRegion {kind:"image",sourceId,version,frameRef:null|Hash,bbox:[x,y,w,h]}
 | TimedRegion {kind:"time",sourceId,version,streamId,sourceRange:Range,
                sampleRange:null|[I64,I64],frameRefs:Hash[],bbox:null|[x,y,w,h]}
// bbox均为方向归一后的左上原点[0,1]，w,h>0，x+w,y+h≤1；原方向变换在probe。
// TextSpan半开，单位原始字节；规范换行/UTF16解码保留SourceMap，不能拿token偏移冒充字节。
Coverage {requested:EvidenceLocator,observed:EvidenceLocator[],gaps:EvidenceLocator[],
  sampledFramePts:Q[],samplingProfileRef:null|Hash,truncated:bool,
  capabilitiesUsed:string[],capabilitiesMissing:string[]}
DependencyRef {artifactId,artifactVersion:I64,selector:JsonPointer,
               selectedValueHash:Hash,sourceUseGrantId}
// VLM自报“95%”没有标定就score=null；engineScore也不跨OCR/ASR/VLM比较。
// 每个inference必须指向输入证据；跨两帧推断运动不能退化成无时码的一句“正在跑”。

AttachmentIngestor.stage(FileToken|TextInput,scope)->Attachment
AttachmentIngestor.probe(id,expectedVersion,CancelToken)->ProbeRef|IngestError
AnalysisPlanner.plan(request,Capabilities,Budget)->AnalysisPlan|NeedsApproval|Unsupported
AnalysisExecutor.execute(plan,lease,cancel)->Stream<Progress|ArtifactReady|Failed>
EvidenceProjector.project(artifactRefs,agentGrant,query,budget)->TextProjection
TextProjection {id,version,sourceArtifactRefs:Hash[],chunks:ProjectionChunk[],
  tokenEstimate:uint,tokenizerHash,sourceUseEpochs:SourceEpoch[],projectionHash:Hash}
ProjectionChunk {id,textRef,citationIds:Id[],kind,trust:"untrusted",priority:uint,
  intentDependencyIds:Id[],observedCoverageRef:Hash}
// LLM不可直接写source file/SQL；Agent只得到获授权ArtifactRef和投影。
// 外部URL不是FileToken；远程拉取和上传均另走受审网络工具。
```

| 可编码路径 | 算法/状态与错误闭合 |
| --- | --- |
| native/analysis/video_probe.cpp + scene_sampler.cpp | 复用第7A的demux/seek/PTS索引，不建第二套AVFoundation主链。方向归一后缩至160×90灰度，保留真实sourcePTS；逐帧MAFD=100×Σ\|Yt−Yt−1\|/(N×256)，score=min(MAFD,\|MAFD−prevMAFD\|)，初值0，阈值10为待测初始配置。候选切点保PTS，相距<0.3s标shortCut而非直接删除。不是I帧检测，更不是语义分场；闪光、快摇、渐变会误/漏检。默认用自有差分实现；可选经许可构建的libavfilter scdet作对照，不能偷偷把默认OFF的libavfilter改成必需。公开n9.1 vf_scdet.c实际也用SAD/差分且释放prev帧。 |
| native/analysis/frame_sampler.cpp | 合并均匀1fps、人工关键时点、候选切点前后最近可解码帧；按PTS排序去重。优先人工点，再切点，再均匀点；超96帧保留均匀覆盖骨架并标未采区，所有真实PTS和选中原因入SamplingManifest。深读传range/question/maxFrames，最多512；0.2..0.3s动作可能完全落在采样间隙，概览不能给“未发生”结论。若只有frameSet能力，mode=orderedFramesAndTranscript，不写nativeVideoUnderstanding。 |
| native/analysis/audio_extract.cpp + asr_stitcher.dart | libavcodec→swresample→16k mono，按实际音频origin与sample索引定位；chunk j从j×29×16000 sample开始。词/segment转回sourcePTS，重叠先按时间交集与规范文字匹配；相同绝对sample区间/文字去重，近似匹配采用重叠词序列并保留两份冲突证据供校正，不拼成不存在的新句。0.5秒片段从29秒窗口输出→source29.5秒。无可靠词对齐只标segment时码，不宣称逐词精确；speakerId=null；手工标注说话人是userAssertion，不推断真实身份。 |
| ocr_port.{mm,kt,cpp} + document_reader | Apple Vision按系统revision查询语言；Android选已打包且ABI/安全验证的ML Kit脚本包，商业许可证据缺口按1C风险提示，不能依赖首次联网下载却说全离线。Windows/Linux可选受审Tesseract包；Web无OCR包时仅文本层/手工标注。OCR保留原字/候选/bbox和引擎分数；视觉模型“看到有人举杯”另存inference，不覆盖OCR。字体/版面/反光导致冲突时并列证据，不按任意confidence最大值替代用户资料。 |
| temporal_assembler.dart | 把图像观察按PTS、ASR按sample、OCR按可见区间合并为时间序列；先排序/区间重叠join，再让具备能力的模型仅在所观测范围提议动作/因果。一个静帧不能证明动作速度或前因后果；仅文字模型可整合已分析文本但标inferenceFromText，不声称亲眼看过视频。真正密集运动/说话人分离是额外能力profile，P1未配置时明确缺失。 |
| task_lifecycle + resource_arbiter | queued→running或waitingApproval→completed/partial/failed；cancel先增epoch，阻止新批次，decoder线程安全点退出，释放FrameLease/packet/swr/临时页图与pin；GPU仍使用的lease按第7A完成栅栏释放。已完成批次可留immutable artifact，但旧epoch不得发布到当前上下文。导出优先，分析让出heavy lease；超时可恢复游标，不自动把本地失败切为付费云任务。错误区分FORMAT_UNSUPPORTED、SOURCE_REVOKED、DECODE_FAILED、MODEL_UNAVAILABLE、BUDGET_EXCEEDED、CANCELED，重试只能纯计算且次数/预算有界。 |

```text
// 同一视觉/视频文本投影格式；自拟合成内容，不代表真实识别结果。
{
 "artifactId":"analysis-synthetic-1","schemaVersion":"1.0.0","kind":"temporal",
 "source":{"assetId":"demo-video","version":"1","blobHash":"sha256:<64hex>"},
 "coverage":{"requested":"source[0,6)","observedPts":["0/1","1/1","2/1","4/1","5/1"],
             "gaps":["source[2,4)"],"mode":"orderedFramesAndTranscript"},
 "evidence":[
  {"id":"e1","kind":"observation","text":"杯身可读文字为DEMO",
   "locator":{"pts":"2/1","bbox":[0.4,0.3,0.2,0.1]},"engine":"ocr-v1","score":0.88},
  {"id":"e2","kind":"observation","text":"请看杯盖",
   "locator":{"samples":["32000","48000"],"rate":16000},"engine":"asr-v1","speakerId":null},
  {"id":"e3","kind":"inference","text":"抽样帧中杯盖位置变化，可能在旋开",
   "supports":["frame@2","frame@4"],"score":null,
   "limitations":["2..4秒没有连续观察，不能确认完整旋开动作"]}
 ],
 "projection":["[e1 OCR source2s bbox] 杯身文字DEMO；不证明商标授权。",
               "[e2 ASR source2..3s speaker未知] 请看杯盖。",
               "[e3 推断 source2/4s] 杯盖可能在旋开；有采样缺口。"]
}
// 这是便于阅读的ProjectionDebugView，不是AnalysisArtifact完整wire JSON；
// 正式持久化对象必须满足上面的闭合合同，hash不可使用占位符。
```

| 复用/失效层 | 精确规则 |
| --- | --- |
| L0字节/解码、L1字面提取 | 同namespace、相同blob/version、区间/页/ROI、方向/色彩/缩放、parser/OCR/ASR版本+语言/参数可复用。引用读取仍校验当前grant，content hash不是权限。两Agent可获同一artifact的独立只读grant，不复制或共享聊天。跨App不共享session/cache，用户导入时重建授权。 |
| L2语义与L3目的解释 | SemanticCacheKey=H(namespace,assetHash,sourceVersion,selector,decodeProfile,extractorVersion,analysisLevel,modelResolvedVersion,promptTemplateHash,parameters,question/intentSliceHash,grantScopeDigest,policyEpoch)。相同图像换问题/模型/ROI/时序采样不能命中旧解释。换主角不使无关的杯身OCR重算，却使“这是不是主角”的上下文解释过期。无法解析的provider别名版本，缓存绑定本次catalog与有效期，不宣称永久可重复。 |
| 覆盖与预算 | ContextCompiler按相关性/权威性/覆盖缺口/新鲜度选chunk，先保当前意图和手改，完整引用不能截掉citation；128/256 token片段长度由实际tokenizer算。预算不足返回PartialProjection{omittedIds,nextCursor}，不截断成否定结论；证据冲突带ConflictGroup{claimIds,reason,status:unresolved}，需要深读/用户选定，不擅自消解。 |
| 依赖DAG与权限撤销 | 依赖边绑定artifact版本、selector与selectedValueHash。父Bible仅改另一角色时，校验选择值相同可记录显式rebase而不重生；像素/源视频内容变了则全部相应证据失效。SourceUseRevoked立即禁止读取/索引命中并使下游stale或revoked；缓存物理删除可后台跑，但授权检查不能等GC。缓存命中时再查epoch，不能以旧lease绕过。 |

存储边界：上述附件、分析任务、会话解释、索引默认在workspace，不加进封闭的ProjectDocument 2.0根字段。只有用户接受的源/候选走既有attachArtifacts成为Asset；采纳的事实/镜头映射Brief/Character/Scene/Shot。可移植证据与制作计划用第8B的已声明扩展，导出前逐个选正文/派生物，重新授权；密钥、批准、token、FTS/embedding缓存不导出。公开图片或视频的研究引用不等于获得商业再利用授权。
