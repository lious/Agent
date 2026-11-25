## 8L · PlayRecipe资产库：四种热门玩法的完整配方

PlayRecipe是现有Harness SkillPackage的受审内容子型contentType=playRecipe、family=workflow_craft，不引入另一套执行器。库通用版本表kind仍为filmCraft，按manifest内容类型选择独立PlayRecipe Schema，不把新字段硬塞进闭合FilmSkillAsset v1。FTS按情绪/用途/主体/节奏检索，按需召回配方与所用Craft refs。只声明槽、模板、白名单阶段与QA；没有任意脚本、路径、网络权限或付款/删除权。

| 配方资产字段 | 存储、升级与安全 |
| --- | --- |
| 版本/闭包 | id/semver、kind、slotSpecs、parameterSpecs、allowedRoutes、requiredGates、steps DAG、skillRefs、qaChecks、licenseRef、示例与封面hash。Project冻结recipe/template/character/skill/profile hash；新库版本不静默替换。deprecated提示迁移，withdrawn或权利撤销实时阻断新生成；已接受媒体按权利政策处理，不悄删用户作品。 |
| 示例/封面 | example.synthetic=true；示例图片和视频必须有独立许可与hash，无合法样片时使用自有矢量示意，不冒充真实生成效果。不得打包网络流行模板的音乐/人物/封面。版权不明资源不自动下载。 |
| Schema与执行 | 导入先zip安全/签名来源/Schema/引用闭包→用户确认→沙箱注册；签名不是提权许可。steps只允许preflight/analyze/plan/confirm/compile/generate/qa/edit/deliver；生成工具仍过全局License/Portrait/Upload/Spend gates。编译到既有Scheduler与Craft白名单EditCommand；未知效果UNSUPPORTED_EDIT_TECHNIQUE。 |
| 版本撤销 | 参数或模板变更生成新版本，旧project pin保持；安全/肖像撤销epoch优先于冻结引用。导出归档记录配方和许可快照、被排除/不可再分发素材；恢复时不自动重发云任务。 |

| 拥抱 hug@1.0.0 | 完整配方/边界 |
| --- | --- |
| 用户/输入 | 纪念/社交合成。三变体：onePersonImaginedPartner=真实单人图1＋明确选择的虚构伙伴；twoPeoplePhoto=含2名已授权人物的合照1走I2V；twoImages=两个单人参考图各1走R2V。稳定leftSubjectId/rightSubjectId，不按文件名重排；R2V单张双人参考不能冒充单主体。 |
| 表单/流程 | 关系/左右角色/侧拥或友好拥抱/中景或全景/画幅与时长→预检人数与许可→逐人视觉证据→接触/遮挡计划→用户确认合成互动与上传→编译→报价生成→手指/肢体/身份/接触QA→NLE合成声明/字幕/配乐→交付。两张图需抠图时只提供用户手动蒙版或已注册ImageEditor，不捏造自动分割能力。 |
| 锁/失败/权限 | 必须分别确认肖像范围；单人图不能自动配另一个真实陌生人。未成年人继续走guardian和provider policy门禁。提示“AI合成互动，不表示人物真实相遇”；手臂穿透、换脸失败只候选拒收/付费重做提案，不自动修成保证真实。锁定字幕/声明不能被局部重做覆盖。 |

```text
【play.hug.two-images@1.0.0；R2V模板】
Image 1所示{{leftIdentity}}在画面左侧，Image 2所示{{rightIdentity}}在右侧。
两人{{contactAction}}，{{framing}}，{{camera}}，{{light}}。
保持各自服装与面部区别，动作轻缓，避免复杂转身；这是合成互动。
【完整填槽示例，两个虚构成年角色，非真人照片】
Image 1所示蓝外套短发岚在画面左侧，Image 2所示米色开衫卷发禾在右侧。
两人向对方靠近并轻轻侧拥，中景，固定机位，柔和室内侧光。
保持各自服装与面部区别，动作轻缓，避免复杂转身；这是合成互动。
参数=wan27-r2v/5s/9:16/2个单人参考；后期独立文字层“AI合成互动”。
若只有岚单图，必须在表单指定“虚构伙伴：禾”，改相应路线并确认；不能从此模板假装第二张图存在。

```

| 小人国 miniature@1.0.0 | 完整配方/边界 |
| --- | --- |
| 用户/槽 | 奇幻短片/创意展示。必填主体参考1、参照物/场景图1（可同图但明确区域）、相对比例意图0.005..0.2、站位/接触点、动作、时长；可选用户提供的前景蒙版/景深意图。默认示例1:20是创作软约束，非真实几何标定。 |
| 路径/交互 | 预检主体/参照物尺度和授权→观察透视/光向/遮挡证据→规划相机高度、接触影、前后层级→用户在图上设锚点/裁剪→单帧已合成走I2V或单主体R2V另以场景规划，不超参考能力→批准→生成QA→NLE文字声音→交付。精确比例只有提供分层素材并走确定性合成才可验证像素尺度。 |
| 失败/编辑 | 浅景深不等于真实微缩几何；比例漂移/接触影缺失/穿模要unknown/拒收。用户可锁站位和手工蒙版，模型不能保证遵守锚点数值。无分层素材时不承诺遮挡精确，允许改成纯艺术幻想示例。若用于商品营销，仍不得因此夸大商品实际尺寸/功能。 |

```text
【play.miniature.contact@1.0.0】
{{subject}}以约{{scaleIntent}}的幻想微缩比例置于{{referenceObject}}旁，{{action}}。
从{{cameraHeight}}观察，保持{{perspectiveAndOcclusion}}，{{contactShadow}}；{{light}}。
【完整填槽示例】
穿黄色雨衣的虚构小人物以约1:20的幻想微缩比例置于普通白瓷杯旁，扶着杯把向上张望。
从桌面低机位观察，保持杯把在人物前方的遮挡关系，手脚接触处有柔和阴影；
窗光从左后方照入。不要把杯子变成建筑或修改杯把数量。
输入=用户已确认的双层合成首帧1；API=I2V/5s；比例只是模型意图，未作真实3D尺度保证。

```

| 动物拟人 animalHumanized@1.0.0 | 完整配方/边界 |
| --- | --- |
| 用户/槽 | 宠物/动画创作者。必填动物参考1、物种/保留特征、拟人程度clothingOnly或uprightCartoon、服装、单一安全动作；可选场景图、角色库版本。无真人肖像时仍需图片版权；真人配音/声音另授权。 |
| 流程 | 预检物种与可见体型→面部/耳尾/毛色证据→拟人层级计划→确认保留/允许变化→I2V或R2V编译→报价→物种面部/肢体/服装QA→NLE字幕音乐→交付。clothingOnly不自动改直立人体；uprightCartoon允许卡通站姿但不替换成人脸。 |
| 限制/回退 | 动物图+人类运动不自动等于可靠动物动捕；motionTransfer需体型/服务实测门禁。复杂烹饪/危险动作可降到看书/挥爪等简单虚构动作；不声称真实动物曾做。用户手改表情字幕保留，重做动作只换候选媒体。 |

```text
【play.animal.identity@1.0.0】
参考中的{{species}}保留{{speciesIdentity}}，拟人程度={{humanization}}。
穿{{wardrobe}}，在{{setting}}做{{safeAction}}；{{cameraLight}}。
不要以人类面孔替代物种面部；这是虚构卡通行为。
【完整填槽示例】
参考中的橘猫保留短鼻口、三角耳、橘色额纹与蓬松尾巴，拟人程度=卡通直立。
穿蓝色围裙，在明亮书桌旁轻轻翻开一本无字绘本；固定中景、柔和正侧光。
不要以人类面孔替代猫脸；这是虚构卡通行为。
输入=1张有权使用的合成橘猫图；I2V/5s，QA检查耳尾/前爪数量与翻页穿模。

```

| 婴儿舞蹈 babyDance@1.0.0 | 默认虚构卡通、真实儿童严格门禁 |
| --- | --- |
| 用户/槽 | 家庭纪念/卡通创作者。默认fictional clothed cartoon infant；必填已授权形象1、seatedClap/gentleSway/smallStep之一、时长/用途；可选合规且体型适配的安全参考运动。真实儿童需明确监护授权、肖像范围、最少上传、provider允许该儿童模式。 |
| 路径 | 预检真实/虚构声明与安全动作→视觉/姿态证据→小幅节奏计划→用户确认隐私与合成标识→I2V软动作；若精确参考运动才选经门禁wan22 motion→报价生成→着装/非性化/安全/身体比例QA→NLE音乐节拍和声明→交付。无支持不承诺逐拍照跳。 |
| 硬门禁/失败 | 真实儿童即使有guardian记录，provider儿童政策未核实仍PROVIDER_CHILD_POLICY_UNVERIFIED阻断；可选虚构卡通而非绕过限制。禁止性化动作/成人挑逗编舞、危险扭转或高跳；不以adult motion任意缩放给婴儿。动作失败只简化到拍手/轻摆或拒收，默认不自动传播分享。 |
| 权限/编辑 | 音乐与参考运动各自许可；监护撤销按rightsEpoch清缓存并阻断新生成。锁定家长手改字幕/私密状态不被recipe覆盖；公开发布是用户另一步确认，不能因为选热门玩法就上传社交平台。 |

```text
【play.baby.safe-sway@1.0.0】
{{fictionalOrAuthorizedSubject}}保持{{clothingAndIdentity}}，在{{safeSetting}}
做{{allowedLowAmplitudeAction}}；固定{{framing}}，动作轻缓，{{light}}。
保持非性化、完整着装与安全姿态；不模仿危险或成人挑逗动作。
【完整填槽示例，默认虚构】
圆润比例的虚构卡通婴儿保持浅蓝连体衣和软布帽，坐在平稳软垫上，
轻轻拍手并左右小幅摇摆；固定全身中景，动作轻缓，明亮柔和室内光线。
保持非性化、完整着装与安全姿态；不模仿危险或成人挑逗动作。
输入=用户拥有权利的虚构卡通图1；I2V/5s，未承诺照参考舞蹈逐拍复刻。
如选真实儿童：无guardian或provider child policy未知，编译后仍不准上传/提交。

```
