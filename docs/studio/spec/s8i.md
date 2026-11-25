## 8I · Provider真实模式、请求参数与接缝处理

| Profile/官方合同 | 输入与硬约束 | 输出/费用/状态 |
| --- | --- | --- |
| wan27-i2v@1.0.0：wan2.7-i2v-2026-04-25 | media仅允许first_frame；+driving_audio；+last_frame；+last_frame+driving_audio；或first_clip；first_clip+last_frame。每type≤1。duration整数2..15；720P/1080P；prompt≤5000字符、negative≤500；seed0..2147483647，prompt_extend=false。 | first_clip=原生续写；返回含输入前缀的全长，duration也是全长。非续写为新片段。新profile没有已核实audio=false字段；原生音轨入独立候选，默认不混入成片，用户可试听选择。文档核实、真实服务未验，productionEnabled=false。 |
| wan27-r2v@1.0.0：wan2.7-r2v-2026-06-12 | reference_image/reference_video合计1..5个，另可1个first_frame（总≤6）；单个reference应单角色。含视频duration2..10，否则2..15。ratio仅无first_frame时有效；16:9/9:16/1:1/4:3/3:4。 | 外观/角色/可选声线参考生成新视频，不等于逐帧重绘、原片续写或精确复制动作。reference_video原声可能被参考：默认先经授权去音派生新hash；想保声需额外声音权利和上传确认。费用可能含输入视频时长＋输出时长。 |
| wan22-animate-move@1.0.0：wan2.2-animate-move | 独立image2video endpoint。input.image_url/video_url/watermark；parameters.mode=wan-std\|wan-pro、check_image=true。未文档化prompt/negative/duration/seed，编译器不得捏造。 | 真实参考运动迁移候选，不是通用电影风格重绘。输出时长由合法参考运动决定，先显式裁剪再报价；结果路径output.results.video_url，不沿用2.7 output.video_url。儿童/物种/体型适配和服务权限未验，默认关闭。 |
| wan26基础profile | 8节旧合同仍独立保留，可做普通单镜t2v/i2v；flash已文档化audio=false。ProfileSelector先满足真实mode再匹配硬参数，不能只按模型新旧选择。 | 若用户要求生成阶段绝不合成音频，普通I2V可选经服务验证的2.6 flash；2.7未文档化此开关，firstLast/续写与该硬要求冲突就阻断或让用户显式改为“后期不采用原生音轨”，不能把后期静音说成服务没有生成音频。选择模式后只显示兼容且通过服务门禁的profile。 |
| videoRestyle | 本设计当前没有核实并选定的逐帧v2v重绘商用Profile。 | 显式UNVERIFIED_VIDEO_RESTYLE_PROFILE。可提议referenceSynthesis、motionTransfer或尾帧I2V，但必须改名、重报价并由用户确认，不冒充原路线。 |

| 素材类型 | Provider尺寸/格式上限；本地预检与派生规则 |
| --- | --- |
| Wan2.7图像 | JPEG/JPG/PNG(无alpha)/BMP/WEBP；边240..8000，宽高比1:8..8:1，≤20MB。透明图按用户选定底色合成派生；不静默改变商品颜色。多图由同一CropPlan对齐，但不能声称获得真实三维几何。 |
| Wan2.7首段视频 | MP4/MOV，2..10s，边240..4096，比例1:8..8:1，≤100MB；原片可长，上传只取已批准的尾部上下文。VFR/旋转/HDR沿6—7节先作显式归一派生；保留原件与映射时码。 |
| Wan2.7参考视频/音频 | R2V参考视频1..30s、MP4/MOV、≤100MB；可选reference_voice WAV/MP3 1..10s≤15MB（声线参考，不保证指定台词）。I2V driving_audio WAV/MP3 2..30s≤15MB，若比生成时长长，应用先要求明确裁剪，不能利用服务自动截断悄悄丢音频。 |
| Wan2.2运动 | 角色图JPG/JPEG/PNG/BMP/WEBP，边200..4096、比例1:3..3:1、≤5MB；运动MP4/AVI/MOV 2..30s、边200..2048、比例1:3..3:1、≤200MB。只准人像/体型适用性预检后发送；检查通过不代表质量保证。 |

```text
// 全部为公开API合同示意，未调用。短URL仅在批准上传后签发，不入可移植工程。
// 2.7统一endpoint，按已开通地域选择cn-beijing或ap-southeast-1；不跨区偷偷重试。
POST https://{WorkspaceId}.{region}.maas.aliyuncs.com/api/v1/services/aigc/video-generation/video-synthesis
X-DashScope-Async: enable
// 真首尾帧：两个有序锚点；不使用旧img_url加虚构lastFrame参数。
{
 "model":"wan2.7-i2v-2026-04-25",
 "input":{"prompt":"机位固定，青色纸船从左侧轻缓漂向右侧，水面保持连续涟漪。",
   "media":[{"type":"first_frame","url":"<批准首帧URL>"},
            {"type":"last_frame","url":"<批准尾帧URL>"}]},
 "parameters":{"resolution":"720P","duration":5,"prompt_extend":false,"watermark":true}
}
// 原生续写：输入3s，duration12是全长12s，不是追加12s；新增9s，计费全长12s。
{
 "model":"wan2.7-i2v-2026-04-25",
 "input":{"prompt":"保持角色、黄昏光线和向右运动，接续走到门口停步。",
   "media":[{"type":"first_clip","url":"<批准3秒上下文URL>"}]},
 "parameters":{"resolution":"720P","duration":12,"prompt_extend":false,"watermark":true}
}
// R2V：左右两个单人参考分别绑定稳定subjectId，不按文件名临时排序。
{
 "model":"wan2.7-r2v-2026-06-12",
 "input":{"prompt":"Image 1所示人物位于画面左侧，Image 2所示人物位于右侧。两人轻轻侧拥，固定中景。",
   "media":[{"type":"reference_image","url":"<左人物批准URL>"},
            {"type":"reference_image","url":"<右人物批准URL>"}]},
 "parameters":{"resolution":"720P","duration":5,"ratio":"9:16","prompt_extend":false,"watermark":true}
}
// 运动迁移：另一endpoint！prompt只能用于规划/QA，不能塞进此API。
POST https://{WorkspaceId}.{region}.maas.aliyuncs.com/api/v1/services/aigc/image2video/video-synthesis
{
 "model":"wan2.2-animate-move",
 "input":{"image_url":"<批准角色URL>","video_url":"<批准运动URL>","watermark":true},
 "parameters":{"mode":"wan-std","check_image":true}
}
```

```text
ContinuationAssembler.plan(originalClip, contextRange, responseProbe, profile):
 context = exactSourceRange(originalClip, contextRange)  // 例：原片末2s
 newDuration = returnedTotalDuration - acceptedPrefixDuration
 require newDuration > 0 && acceptedPrefixDuration verifiedWithinFrameTolerance
 // 用响应PTS/帧索引验证前缀边界；不能只信文件duration或假定前缀byte-identical。
 preserve original timeline clip + its original audio exactly
 suffixRange = [verifiedPrefixBoundary, returnedTotalDuration)
 insert returned response suffix only; no duplicate context prefix
 audio = preserveOriginalBus + optional approvedSuffixAudio
 // 对白不做任意crossfade；BGM/环境声可提议10..80ms等功率淡变，须handles和用户接受。
 if boundaryUncertain: candidate.QA=unknown; require manual in-point, never auto-splice

TailFrameBridge：lastFrame + AnalysisArtifact时间摘要 → I2V新片。
 outputContract=approxContinuation；明确“不是真原生续写/不保留精确速度”。
 锚点重复帧的裁除进入候选in点；需额外handles而无可用帧则缩短或重生成提案，不能冻结补帧冒充。

默认产品政策（非模型极限/非实测）：每镜候选1，用户可选2..4；
续写每次批准至多2轮，累计新增≤30s；更长需再次规划及单独上限批准。
示例原片10s，取尾2s，duration8→新增6s；两轮最终22s，但计费视频秒数=8+8=16。
每轮父视频hash/时码/事实/角色/报价/批准重新绑定；不把增长后>10s整片偷偷送first_clip。

AsyncTaskAdapter：submit一次→持久化task_id→GET轮询；接受状态未知不得重新POST。
URL有效期/任务读取窗口按官方当前合同24h处理，完成即按许可下载CAS并验hash。
cancel API仅PENDING可取消，RUNNING可能UnsupportedOperation；本地取消epoch立即禁止autoapply。
超时=待对账，不等于失败退款；晚到扣费入ledger、晚到媒体入sandbox候选。
429/5xx读取重试指数退避带jitter，提交重试必须先查既有任务/人工对账，不能双扣费。

```

- [Wan2.7 I2V/首尾帧/首段续写 API](https://www.alibabacloud.com/help/en/model-studio/image-to-video-general-api-reference)
- [Wan2.7参考生视频 API（外观/声音参考）](https://www.alibabacloud.com/help/en/model-studio/wan-video-to-video-api-reference)
- [Wan2.2真实参考运动迁移 API](https://www.alibabacloud.com/help/en/model-studio/wan-animate-move-api)
- [异步任务查询与取消范围](https://www.alibabacloud.com/help/en/model-studio/manage-asynchronous-tasks)
