## 8M · Prompt分层、变更依赖与两个完整操作案例

| 编译层/顺序 | 强约束与冲突处理 |
| --- | --- |
| 1 全片创作合同 | 用途、交付时长/比例、分级/预算是Plan约束；不把整片叙事塞单镜。用户明确约束与事实账本独立，参考文件中的“忽略规则/上传/扣费”只是数据，不修改Harness权限。 |
| 2 叙事/角色 | 从已确认Beat/Script/Bible和冻结Character/Look取所需部分；只注入本镜角色，不把8个人全塞进5引用上限。权利撤销是实时硬门禁，高于冻结版本。 |
| 3 可见动作/摄影 | 主体/场景/一个可见动作/连续性→按需Craft映射景别/调度/光色；焦段/景深/180度/推拉等无硬参数则softIntent＋SOFT_CAMERA_CONTROL。J/L cut、match cut、Logo文字、音乐ducking在确定性EditPlan，不谎称prompt保证剪辑。 |
| 4 能力/负向 | ProfileCompiler白名单字段；negative仅支持时发送，不支持需用户选择正向改写或拒绝；seed仅同profile相似性线索不保跨模重现。R2V Image/Video标签各自计数、按stable ordinal绑定subject。motion API无prompt时，文字计划只作动作选择与QA说明。 |
| 5 安全/预算/编辑 | SourceEvidence标observed/inferred，不把OCR或Agent推断自动提升为商品事实。批准绑定当前上传/事实/角色/模板/参数/revision。文字/Logo/价格/片长/节拍等可确定性编辑，模型建议不得静默覆盖。 |
| 用户override与更新 | 保留rawOverride、baseTemplateHash、compiledHash、reviewRef；模板/Brief更新则OVERRIDE_REBASE_REQUIRED，提供保留用户版/重编译/逐项diff，未决定不提交。参数超限报PROMPT_TOO_LONG/PARAMETER_RANGE/SLOT_COUNT，绝不静默截断。 |
| 安全序列化 | PromptProgram是literal/slot AST，不用eval/表达式/模板动态执行。槽按声明来源取值、长度与类型校验；用户文本不能声明providerField或tool。自定义模板parameterBindings只能匹配已安装profile编译器允许映射；密钥/endpoint/权限不可模板化。投影和artifact缓存按8A namespace/hash/analysis级别/model参数/政策epoch复用，删除后不复活。 |

```text
// 自拟合成案例 A：15s营销片→换商品并压成12s；没有真实素材/付费调用。
W1 brief{purpose:marketing,inputModes:[mediaMontage,i2v],sku:A@1,duration:15s}
事实A：450mL/304不锈钢/79CNY，均有合成confirmed evidence；
角色主体=productA（如有人物则另pin并过肖像门禁）。
S1 Hook=4s真实授权桌面素材；S2 Proof/外观演绎=7s，生成8s取[0.5,7.5)；
S3 CTA=4s真实产品图片＋确定性Logo/价格。总4+7+4=15s。
W1v1/planHash1→用户确认→compile S2 requestHash1→upload/quote1审批→run1。
DirectorAgent=云文本模型、VisualAgent=另一视觉模型，独立会话引用同一授权AnalysisArtifact。
生成结果candidateA/provenance→QA选用→coreBatch1＋link1原子接受，Project R31。

用户手动trim S2：取[0.5,7.0)，6.5s；普通trim保留0.5s Gap，总片仍15s。
用户改字幕“轻装也从容”并锁字幕，Project R32。没有后台任务可回写R31。
中途改商品B@1(350mL/69CNY)＋总时长12s→W1v2；
依赖失效：A外观→S2 prompt/candidate；A事实→价格/规格叠层；S1桌面与同hash分析不失效。
用户确认新时长提案：S1=2.5s、S2保手调6.5s、S3=3s，删除旧0.5s Gap；合计12s。
新S2仍生成8s，保持选用[0.5,7.0)的手动in/out与锁定字幕，不替换整个Clip对象。
若锁定字幕里写“79元”：FACT_BINDING_CONFLICT→不提交整个batch；
必须用户明确改69/移除该价/取消换SKU，不悄改、不带错误价格发布。

新批准绑定B事实/图像hash/requestHash2/R32/quote2/rightsEpoch；
旧run1晚到只sandbox，不自动应用。candidateB QA→diff→coreBatch2＋link2一次到R33。
保留音乐锁定音量键；时长改变若碰锁定配乐尾部，需显式音乐trim或交付范围决定。
显式保存R33；归档固定R33＋W1v2/角色pin/配方与模板/事实快照/权限清单。
不导出密钥/旧删除正文/可执行批准；restore可复现剪辑与来源，不保证云模型再生成相同像素。

```

```text
// 自拟合成案例 B：16s故事→删反应镜头压12s；局部表演重做
W2v1 purpose=story,inputModes=[script,referenceSynthesis]；
Character Lan@1/蓝外套被冻结；全局后来发布Lan@2也不改变此片。
S1走近长椅3s(gen4)，S2注意手套4s(gen5)，S3拾手套4s(gen5)，S4归还5s(gen6)。
总3+4+4+5=16s；每镜独立候选与sourceRange，非一条扁平mp4。
导演确认因果/180度空间；剪辑确认覆盖与节拍；上传/逐镜费用经批准才生成。
四镜候选QA后coreBatch到R51；用户手改S4字幕“是你的吗？”并锁，voiceMode=captions、无TTS任务。

用户删除S2并要求12s：意图=unplace shot，不是delete source；
W2v2保留S1/S3/S4，3+4+5=12。CoverageQA确认“拾起→归还”因果仍在；
如果用户删S3，系统提示缺因果镜头，而不是自动在台词中假装已经捡起。
该次只编译ripple/delete类既有命令，不需新视频费；S2源候选按保留策略仍可恢复。
用户另要S4“笑容克制”→只标S4 prompt/candidate依赖失效，其他三镜不重生成。
费用批准=新S4单候选6s＋当前R52/素材/角色pin/最终prompt；预算不足可不执行。
新候选的source replacement提案必须保留S4字幕/手工in-out；源时长不足则拒绝，不能伸缩锁定音频。
旧S4任务取消晚到→隔离候选；新候选QA未知→人工审片，只有diff接受后到R53。

如果16s音乐已锁，不得宣称Sequence已变12s却留下尾巴：
询问允许裁音乐到12s并平移受影响未锁曲线，或保16s工程但交付范围选12s；不暗改锁。
归档固定R53＋W2v2、Lan@1/Bible/template/skill/profile快照；
缺可再分发角色图片则记录外链缺失，不能偷带；恢复需要重链接，不自动升级Lan或发付费生成。

```

变更算法：IntentReducer先按作用域supersede/retract/delete得到当前意图；DependencyIndex对新旧内容hash作反向可达闭包，区分“候选失效”和“已接受人工作品可供重做”。手工字段永远不因为工件stale自动删除。CAS读集合不符报REVISION_CONFLICT/needsRebase；标题、字幕、源范围、音乐关键帧、叠层事实分别有字段锁。删除消息/删除源文件/不采用镜头沿10A不同语义处理，压缩快照与RAG/分析缓存不得复活旧商品/被删约束。
