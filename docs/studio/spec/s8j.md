## 8J · 营销、展示、故事、脚本：四种不同工作台

| 营销带货 marketing | 具体流程、字段与编辑边界 |
| --- | --- |
| 入口/槽 | 商家/运营选“成交短片”；必填sku＋ProductIdentity版本、正面图1、已确认facts≥1、目标人群/痛点/CTA、总时长/比例；可选细节图0..3、真实演示视频0..3、logo1、品牌色、禁用功效、已授权出镜人。前/细节图不能随意换序；CropPlan显示商品完整区域与安全边距。 |
| 预检→分析→规划 | probe/授权/过期价格预检→ProductObservation(可见包装/OCR证据，不自动变事实)→Hook/Pain/Proof/CTA beats与frameBudget。Proof必须指向真实素材或confirmedFact；生成使用画面标“演绎”，不能充当防水/保温/医疗/销量证据。 |
| 确认→编译→生成 | 确认事实表、分镜、实拍与生成标识；每镜只编译一个可见动作。确认上传、模型、时长、候选数与quote后生成；同一SKU参考绑定冻结。功效/价格仅来自有效confirmedFact，用户自由prompt改写后营销审查变stale。 |
| QA→NLE→交付 | QA比较外形/包装/手部/用法及语义夸大；机器unknown必须人审。Logo/价格/折扣/CTA用确定性ImageDocument/Caption叠层，字幕可逐字改；发布前核验fact有效期。手改价格与新SKU冲突时FACT_BINDING_CONFLICT阻断，不能为保手改而发布旧价。 |
| 失败/回退/费用 | 商品变形→换候选或用户批准局部重做；仍不准则用原件定帧/真实演示，标确定性编辑，不假称AI修复正确。缺事实只做不含功效与价格的外观片，须改成showcase确认。无有效报价/权利不上传、不扣费；自动重做默认0次。 |

```text
【自拟营销规划模板 marketing.hook-proof-cta@1.0.0；用途=planning，不整段发单镜模型】
输入：商品={{sku}}/{{productVersion}}；人群={{audience}}；痛点={{pain}}；
已确认事实={{confirmedFactsWithEvidence}}；CTA={{cta}}；总帧={{frameBudget}}；
可用真实素材={{evidenceClips}}；禁用宣称={{forbiddenClaims}}。
输出：Hook/Pain→可验证Proof→CTA三段；每段给shotId、帧数、可见动作、
真实素材或生成路线、事实引用、独立文字层、声音来源。没有证据不编造演示。
【填槽规划示例，所有商品/事实均合成】
SKU A/v1“青岚随行杯”；人群=通勤者；痛点=桌面物品杂乱；
事实=f.capacity:450mL、f.material:304不锈钢、f.price:79CNY（合成确认记录cA）；
CTA=查看商品详情；总450帧/30fps；真实素材=自有桌面收纳短片；
禁用=保温小时数/防漏/防水/健康功效。分镜120/210/120帧。

【逐镜可复制模板 marketing.product-shot@1.0.0】
参考图所示{{productName}}保持{{shapeMaterialColor}}与{{packaging}}。
{{setting}}中，{{visibleAction}}。{{cameraIntent}}，{{lightIntent}}。
只呈现当前可见动作，不增加功能、配件或表面文字；为后期文字保留{{textSafeArea}}。
【填槽后的最终正向prompt；API另传8s/720P，单首帧I2V】
参考图所示青岚随行杯保持直筒杯身、青色哑光表面、银色杯口与原包装。
浅灰通勤桌面上，一只手将杯子缓慢放到空出的桌面中央。
固定中近景，仅轻微推进，柔和窗侧光。只呈现放杯动作，不增加功能、配件或表面文字；
上方20%留作后期文字区域。价格79元、Logo和CTA均不由模型绘字。

```

| 商品展示 showcase | 具体流程、字段与编辑边界 |
| --- | --- |
| 入口/槽 | 电商详情/设计展示。必填SKU版本、正面1＋细节图1（可用同一原件不同明确crop但显示同源）、材质/颜色/包装、展示重点1..3；可选侧背面0..3、真实旋转视频1、尺寸证据。需要背面却无参考时不让模型杜撰成已知商品事实。 |
| 预检→规划 | 核验图像清晰度/遮挡/白平衡/授权→Observation与不确定区域→英雄镜头/材质特写/包装收尾，镜头表逐一标“已见参考区域”。三视图不是精确3D重建；焦段/转台角度为软建议，精确旋转用真实视频或另立3D资产路线。 |
| 确认→交付 | 确认展示区与可生成区域→编译单镜→逐候选与参考并排QA→NLE裁剪/背景/标签/可选音乐→导出。用户可锁Logo层/裁剪/字幕；换SKU只重做其依赖，不能带旧包装复用。形状漂移拒收或回退原图推拉，明确Ken Burns不是生成视频。 |
| 失败/费用 | 反光材质/手部遮挡/字样常为质量风险；禁无上限重试。可先2s以上最短可用样片一次报价验风格，再确认全批；预览也计费须说明。缺细节证据则删该镜头或让用户补图，不放大模型想象当细节。 |

```text
【showcase.material-detail@1.0.0，逐镜模板】
参考中{{sku}}的{{visibleRegion}}保持{{identityConstraints}}。
以{{shotSize}}呈现{{surfaceDetail}}，仅做{{singleMotion}}；{{lightIntent}}。
不展示未提供的背面或内部结构；标题、尺寸和Logo交给独立编辑层。
【完整填槽示例】
参考中SKU LAMP-A的正面灯罩和底座保持奶白圆柱灯罩、深灰圆盘底座、无新增开孔。
以特写呈现已拍到的织物纹理，镜头仅缓慢横移；宽柔光从左侧掠过以显示纹理。
不展示未提供的背面或内部结构；标题、尺寸和Logo交给独立编辑层。
输入=正面原图+已确认的局部crop；该镜执行I2V只送选定细节首帧，另一图用于QA不冒充多图输入。
参数=5s/720P，后期选4s；材质“织物”取合成确认说明，不推导阻燃/环保性能。

```

| 故事成片 story | 具体流程、字段与编辑边界 |
| --- | --- |
| 入口/槽 | 短剧/动画/叙事创作者。必填logline、主角/动机/阻力/转折/结局、场景、时长与分级；可选剧本文件1、角色库1..8、场景参考0..8、声音/音乐。首版一片建议≤8主角，provider每镜参考数量另受硬约束，超限拆镜或拒绝。 |
| 预检→规划 | 8B完整专业流程：brief→treatment→节拍→分场脚本→breakdown→Bible→导演阐述→覆盖镜头表→animatic。编剧Agent交ScriptArtifact，导演交Beat/CoveragePlan，摄影交ShotIntent，剪辑Agent交EditPlan；各可不同模型，只有确认工件作下一步输入。 |
| 确认→编译→生成 | 用户确认故事因果、角色版本/造型、场景空间和animatic节奏后逐镜生成；180度/视线/动作匹配记为ContinuityConstraints。镜头prompt只描述当前可见行为，J/L cut在NLE命令层；长对白按真实音源时长调整，不默认有TTS。 |
| QA→交付 | 角色/道具/屏幕方向/时间光色/动作衔接/叙事因果逐项QA；不能把相似脸分数视作身份保证。先粗剪→精剪→对白/声音/音乐→调色→交付。锁定表演/字幕/音量曲线分别生效。缺覆盖先重剪，确有必要才提议补镜并重新审批。 |
| 失败/费用 | 删除镜头触发覆盖/因果检查，而非自动重生成全片；角色新库版本不更新旧pin。连续性失败可换候选、过肩/插入镜头缓解，但不能掩盖人物突然换脸。预算逐镜公开，已生成未用候选也可能计费。 |

```text
【story.causal-beats@1.0.0，planning模板】
故事={{logline}}；主角={{pinnedCharacter}}；目标={{goal}}；阻力={{obstacle}}；
转折={{turn}}；结尾={{ending}}；场景={{locationBible}}；总时长={{duration}}。
给有因果关系的节拍与覆盖镜头表：每镜可见动作、前后状态、空间方向、
道具接续、对白/VO是否有真实音源、可删除性。不得靠字幕解释不存在的关键动作。
【填槽示例】
故事=岚在车站长椅发现遗失手套并归还；主角=虚构Lan@1/蓝外套；
目标=赶车；阻力=注意到他人遗物；转折=停步拾起；结尾=还给回头寻找的人；
场景=黄昏站台，列车方向向右；总16秒。镜头=走近3/注意到4/拾起4/归还5。

【story.visible-action@1.0.0，逐镜模板】
{{characterAppearance}}在{{setting}}，{{oneVisibleAction}}。
{{framingAndMotion}}，{{lightAndColor}}；保持{{continuity}}。
【完整填槽prompt，S3】
蓝外套短发的虚构角色岚在黄昏站台长椅旁弯身，用右手拾起椅面上的红色手套。
侧面中景，固定机位，暖色侧光与偏冷背景形成克制反差；
岚始终位于长椅左侧，视线落向右下方，手套只出现一只，外套与上一镜一致。
参数=参考角色单图R2V/5s，后期选4s；无独立台词音源，采用可编辑字幕而非偷偷TTS。

```

| 脚本生视频 script输入轴 | 具体流程、字段与编辑边界 |
| --- | --- |
| 入口/槽 | 编剧/课程/品牌文案持有者。必填脚本文本或文本文件1、purpose、总时长、语言；可选角色映射/参考图/实拍/外部已授权旁白。文件格式/编码/分页/大小沿8A，不读任意Office宏/远程链接。 |
| 解析→分析 | ScriptParser输出Element{id,kind:scene\|action\|dialogue\|voiceOver\|onScreen,speakerId:null,text,sourceOffsets,pageRef,estimatedSpeechMs, factEvidenceRefs[]}。模糊说话人、INT/EXT缺失、引用事实未确认都进入issues，不瞎分配角色或改写为既定事实。 |
| 规划/确认 | 按场景分组→动词可拍性→拆镜与因果→估算朗读/停顿→整数帧预算。voiceMode必须明确none/captions/uploadedAudio/nativeTrial，没选TTS不创建tts job；nativeTrial不是独立可控配音。用户可改段落、旁白、屏幕文案、镜头时长，sourceOffsets与版本一起更新。 |
| 编译→交付 | 对白与VO不直接塞进无台词能力的视觉prompt；visualAction单独编译。实际上传音源测得时长优先于字数估计，超预算提示缩文/延时/删镜。逐镜生成→因果/说话人/字幕QA→NLE编辑→交付。删一句不删原文件，未改镜头缓存复用。 |

```text
【script.to-shotplan@1.0.0，planning模板】
脚本元素={{elementsWithSourceOffsets}}；已知说话人={{speakerMap}}；
可用事实={{confirmedFacts}}；voiceMode={{voiceMode}}；预算={{totalFrames}}。
按scene/action/dialogue/voiceOver/onScreen分类；返回每段source引用、
可见行为、候选镜头、帧数、声音来源与未决问题。对白不是摄影描述，未知说话人必须提问。
【完整填槽示例】
[0..8 scene] 黄昏，站台。
[9..23 action] 岚拾起长椅上的红手套。
[24..34 dialogue speaker=Lan] “是你的吗？”
说话人映射=Lan→虚构Lan@1；事实=空；voiceMode=captions；总360帧/30fps。
输出：场景建立90帧；拾手套180帧；伸手询问90帧，台词只作可编辑字幕。
视觉单镜最终prompt：蓝外套短发岚站在黄昏长椅旁，右手托起一只红手套望向画面右侧；
中近景固定镜头，保持站台暖冷光色，不在画面生成文字。
API=R2V/5s，剪辑取3s；没有TTS请求，也不声称原生音频会准确说出台词。

```
