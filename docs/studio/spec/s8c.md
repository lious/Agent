## 8C · 两套可拷贝制作模板与变更全过程（自拟，非官方模板）

下面模板用于规划Agent，输出经schema/权限验证后才成为StageProposal。镜头prompt另交生成provider；模板中的“禁止收费/删除”等是本App的工具策略，由ToolRuntime强制，不依赖模型自觉。输入事实/附件始终放数据区，不能借文件文字改角色权限。

```text
TEMPLATE studio.film.product-ad@2.0 / planner output schema production-plan@1.0
任务：为目标受众制作可编辑的产品广告，不发明卖点、不直接调用生成服务。
必填：productName，verifiedClaims[{text,evidenceRef}]，audience，objective，cta，
 referenceAssets[{id,version,rightsId,role}]，targetSeconds，aspect，deliveryPreset，
 budgetCeiling，audioPolicy，brandPolicy，manualLocks[]。
可选：protagonist，treatmentPreference，offer(含有效期/证据)，forbiddenClaims[]。
步骤：
1. 列事实/未知/冲突；必要事实缺失时返回questions，不猜功效/价格。
2. 提出logline和hook→proof→hero/CTA的情绪弧；每个beat写为何值得一个镜头。
3. 拆单一可见动作；写连续性Bible、摄影意图、参考用途与授权缺口。
4. 给shotList：beat、镜长、生成时长/handles、景别/运镜/光色、主体/动作/画面方向；
   仅在有意义时写等效焦段。生成事实无法证明的功能时不要用作证据镜头。
5. 给editPlan：精确cut、CTA/Logo独立图层、VO/音乐/环境声独立轨，
   比较至少一个克制剪法与一个反差剪法，但仅提交用户选定方案。
6. 返回上传清单/按生成秒数计的报价请求/风险；等待用户确认，不收费。
输出：{questions[],logline,treatment,beats[],bible,shotDesigns[],editPlan,
       finalShotPrompts[],fieldMappings[],uploadPlan,quoteRequest,changeDependencies[]}
每镜prompt模式：{可见主体及已授权外观}；{场景}；{唯一动作}；
 {景别/必要视点}，{一种主要运镜}；{动机光/材质/色彩}；
 {承接本镜的必要连续性}；{给独立文字层留出的构图空间}。
I2V模式：不要重新描写与参考冲突的外观，正文重点写动作和相机运动。
图像内文字/精确Logo不由模型承诺；negative仅provider profile明确支持才输出该字段。

填槽（合成）：
productName=蓝色DEMO杯；verifiedClaims=[外观蓝色/产品已授权正面图]；
不声称保温/健康效果；audience=通勤者；objective=记住产品；cta=轻装而行；
target=15秒，9:16，30fps；audio=providedMusic，品牌字由编辑层；
lead=成年通勤者，海军蓝外套；参考图/人物授权是示例占位，并无实际素材。
logline=从匆忙到从容，一个醒目的日常随行物。
S1 hook 5s / gen6s：中景，通勤者从左向右走过清晨站台，慢速侧移跟随，
柔和侧逆光、蓝灰背景，单一走路动作，头顶留字幕空间。
S2 detail 5s / gen6s：产品近景，蓝色杯身在简洁暖灰台面缓慢旋转，
柔和条形高光，背景干净，主体几何保持稳定；画面没有人物/手。
S3 hero 5s / gen6s：以授权杯图为首帧，镜头缓慢推进，杯身保持稳定，
柔和晨光，构图下部留出独立CTA区；不要求模型写DEMO或价格。
编辑：S1[0,5)，S2[5,10)，S3[10,15)，hard cuts；
source各取[0.5,5.5)，两侧0.5s handles；CTA单独Caption/Logo layer；
音乐原音不改，按获授权资产精确裁切15s；不把音乐版权交给视频provider假定解决。
```

| 广告：用户动作/版本 | 失效、命令、费用与持久变化 |
| --- | --- |
| 初次确认与生成 | Brief b1、Bible bible1、ShotDesign s1/s2/s3@1；Director使用云文本模型、DP用独立云视觉模型、Editor本地Qwen。用户确认三镜规划后，Approval A1绑定prompt/resource/revision/quote/upload；Run R1..R3各gen6s，预算预留18生成秒；candidateReady只写沙箱，选take后batch attach/insert/caption→Project rev20。没有实际价格/调用。 |
| 手动trim与修字幕 | 用户normal trim S1 out −0.5s→rev21，S1[0,4.5)，显式Gap[4.5,5)，后两镜不动；用户把CTA修成“轻装而行”→rev22，caption.text加manual lock，captionAnchor=clipLocal。保存命令逆操作，AI不重写该字。 |
| 中途“主角改为年长通勤者，删S2，总长12秒” | 三个独立有效意图：lead i2 supersedes i1；shotOrder删除S2；duration=12 supersedes15。bible2只改lead字段，s1/prompt1及相关外观分析解释stale；S3产品图OCR与像素分析不失效。删除S2是提议移出工程，不删除源文件/已付费候选。预览提议保留S1手工4.5秒、S3延至7.5秒，并显式关闭那0.5秒Gap；未确认不修改rev22。 |
| 重算而非偷偷拉伸 | S3旧源6秒，sourceIn0.5+目标7.5=8秒，越源，不能直接trim到12；为保0.5s两侧handle需≥8.5秒，Wan整数时长上取9。新S1 gen6保留手改4.5，S3 gen9；只给这两镜新Approval A2，额外15生成秒，累计33而非最终12秒。旧S2已完成部分不承诺退款；若远端运行中只请求取消/对账。 |
| 局部替换/导出 | 新take只替换对应source；S1取source[0.5,5)，duration4.5；S3取[0.5,8)，duration7.5。受审batch先移除S2相关Clip/其scene引用、ripple删除明确Gap、replace source、extend S3，经当前rev CAS提交rev23；S1[0,4.5)、S3[4.5,12)。CTA文本锁不写，clipLocal锚自动迁到新S3时段；此时若用户又修字需重基placement，不自动覆盖。保存RenderRecipe(rev23,12s,preset)后按共享FFmpeg链输出。 |

```text
TEMPLATE studio.film.short-story@2.0 / planner output schema production-plan@1.0
任务：为短剧情片做可检验的前期规划与逐镜prompt，先讲清人物选择，再设计镜头。
必填：logline，theme，protagonist{id,motivation,appearanceRef,rightsId}，
 conflict，ending，sceneLocations[]，rating，targetSeconds，aspect，
 dialoguePolicy，budgetCeiling，continuityConstraints[]，manualLocks[]。
可选：supportingCharacters[]，propMotif，soundCounterpoint，motivatedRuleBreak。
步骤：
1. 写treatment：人物欲望/阻碍/选择/结果，区分观众已知与角色已知；
   每beat列“新信息/情绪变化/所需覆盖镜头”，不把广告CTA硬套进故事。
2. 分场脚本给INT/EXT、地点/时间、动作与对白；Breakdown列角色/服装/道具/声源。
3. Bible规定空间轴线、出入方向、服装、道具状态、光向；写导演阐述和例外理由。
4. 镜头表含主镜/反应/插入，必要的视线/动作匹配，禁止同镜塞多个地点/复杂切换。
5. 先用分镜静帧做animatic验证叙事时长，再提出每镜生成请求。
6. 把J/L、反应停顿、蒙太奇顺序/省略放editPlan；模型prompt只写单镜可见动作。
7. 输出可单独改的VO/对白/字幕和音效计划；精确对白由独立录音/TTS已授权profile完成，
   未配置口型模型时不能保证口型一致，也不默认克隆声音。
输出同上，加{continuityChecks[],informationFlow[],alternativeCoverage[],soundPlan}。
每镜prompt模式：镜头{shotId}，本镜叙事功能{beat}。
{当前主角的已授权外观/服装}在{场景/光线/时间}做{单一动作}，情绪{具体可见表演}；
{景别/角度/机位与画面方向}，{主要运镜或固定}；
保持{只与本镜有关的Bible约束}。声音/剪辑建议另列，不混进可见场景描述。

填槽（合成原创故事“门外的灯”）：
logline=晚归者以为门外脚步是威胁，终于发现是一盏为她留着的灯。
theme=误解转成善意；冲突=不敢开门；结尾=门外无人，台阶上有亮着的小灯；
lead=穿灰外套的成年女性A；location=同一公寓门内/走廊；30秒16:9、30fps；
无角色对白，独立授权脚步/钟声/轻呼吸；不可凭音乐暗示真实犯罪事件。
导演阐述=受限视点，先不给脚步主人反打；冷色门内与暖灯形成有叙事目的的反差。
Bible=门在画面右，人物看向右；走廊轴线侧A，灰外套，灯为暖色圆形小灯。
S1 7.5s/gen9：中远景，灰外套女性站在门内向右侧门看去，固定机位，
窗外冷色月光，室内安静，只做转头这一动作。
S2 7.5s/gen9：女性面部近景，视线朝右，缓慢靠近门，镜头轻推，
左侧柔冷光，表情由紧张转为迟疑；同一外套和发型。
S3 7.5s/gen9：门内侧中景，女性的手缓慢触到门把，机位留在同一轴侧，
画面保持门在右，动作克制，浅景深意图，不换地点。
S4 7.5s/gen9：门外台阶圆形暖灯近景，无人物/手，固定机位，
暖光轻微闪动，走廊背景稳定；本镜不依赖主角外观。
编辑初版=4×7.5秒，源各取[0.5,8)；冷→暖反差在选take/受控GradePlan中验证，
不能保证prompt产生精确色温。S2画面入点7.5s，门外脚步从7.1s进入，J=0.4s；
可用独立foley轨，若用镜内音须有0.4s head handle。S4揭示后留反应停顿，
不强加每镜转场；钟声平静作为视听反差，不用跳吓音硬替代叙事。
```

| 叙事片：中途变化 | 选择性重做与最终拼装 |
| --- | --- |
| 计划/animatic/生成 | storyBrief v1、treatment t1、bible1、shotList l1；用户先确认故事和视听方案，再批准4×9=36生成秒的四镜。临时animatic无paid job；正式候选分别关联s1..s4、promptHash、模型版本、参考权利。用户手调钟声音量并锁对应gainEffect.parameters.gainDb，字幕“有人吗”修字后锁text，即使片中无对白也可作为内心文字层。 |
| “换成年长女性，删触门把这镜，24秒” | Intent按明确角色ID supersede lead，RemoveShot指向s3，不猜“她”是谁；有多个女性时先提问、不发任务。s1/s2需新外观，s3移出镜头表与时间线；s4没有人物，仅依赖灯/地点字段，Bible改主角不应使s4重生成。新shot order[s1,s2,s4]，各8秒；s4旧gen9源可取[0.5,8.5)，头尾各0.5秒，不需要新费用。 |
| 依赖/费用/锁定 | 新s1/s2各gen9，额外18生成秒，经新审批后执行；累计54生成秒，s3旧任务花费照对账，不能因删除镜头当作0成本。J切的独立脚步按新c=8移到7.6，若soundCue.range被锁，先提出冲突供用户选择，不以“保持节奏”绕过锁。gain与字幕text锁不变；无关已授权foley/ASR不重算。 |
| 结果与变更记录 | 候选抵达只写stage/candidate记录；用户选take后一个batch更新creative镜头引用、删除s3 Clip、替换s1/s2源、各镜trim至8秒并布局[0,8)、[8,16)、[16,24)，重新验证源handles和音画锁。最终24s是NLE事实，叙事情绪、人物一致、灯光反差是人工看片验收，不是合成测试已证明的电影质量。 |

案例中的人物/产品图/时码都是合成占位，没有读取或上传实际照片。所有昂贵请求前展示最终prompt与字段映射；用户直接改prompt后保存新PromptDraft版本，若与当前主角/时长/Bible冲突则标customOverrideNeedsReview，不默默覆盖用户改字，也不把过时prompt继续当最新版。
