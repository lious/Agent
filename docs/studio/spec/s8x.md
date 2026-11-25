## 8X · 15秒四镜：先有声预演，必要动态再投入

合成用途示例，不代表产品转向动态漫。9:16、24fps、48k。角色青禾v3/庭院v2冻结；授权本地TTS或用户录音。以下sample数是测试fixture，不是音色/语速实测；真实运行先probe量时。

| 镜头 | 执行/对白 | 边界 |
| --- | --- | --- |
| S1 [0,72) 3秒 | 庭院静帧＋2D缓推、风声；本地共享编辑图。 | 安全裁切，不称2.5D；无视频模型费用。 |
| S2 [72,168) 4秒 | 画外音“等风停，我就出发。”fixture105600/48000=2.2秒，余1.8秒留呼吸/反应；花枝/人物/庭院分层视差。 | mask/depth或planes/补全背景齐备才真2.5D；否则用户确认2D替代，不偷付费补全。不承诺口型；字幕手改text锁定。 |
| S3 [168,264) 4秒 | 衣摆花瓣起、人物抬眼；i2v_micro，自有GPU已验证profile或授权云，按原生合法长度生成再取4秒。 | 确认参考图/许可/上传/费用/能力；候选手部漂移只修S3。剩一次预算用完即停；可提议静帧替代但不能默默降级。 |
| S4 [264,360) 4秒 | 山门反打静帧或明确选微动；“这次，不再回头。”fixture67200/48000=1.4秒，余2.6秒音乐片尾。 | 字幕/Logo确定性叠层，不让模型画字；新动态另验capability/quote，本地静帧版本可预览。 |

| 事件 | 实体/状态变化 |
| --- | --- |
| 预演批准 | p1/r10、plan v1、角色v3/场景v2、voice/caption/animatic a1入CAS，approved a1；S2分层/S3视频费用单列并绑定q1上限。无声预览不算有声批准；台词超长提示缩句/加时/改镜，不擅自加速。 |
| 调度 | Director用本地模型、Visual用另一获授权模型；Handoff仅artifact/hash+约束。PlanGraph并行S3与不冲突本地渲染，受GPU租约/NLE单写者/手调锁限制，LLM不能直改DB。 |
| 删镜改时长 | 用户删S4并改12秒→v2提议3+4+5秒共288帧；S3原4秒不足则明确提议持尾帧1秒或新生成，不能改fps偷变速。用户选hold→注册编辑提案。删镜不删源、不撤已付job。 |
| 改台词 | S2新句只重算TTS/对齐/animatic与cost binding；字幕手改text锁保留，提示与声音不一致，用户逐项同步。不依赖台词的S1/S3画面保留；启用口型才失效关联生成。库升级角色v4不替换pin v3。 |
| 晚到与归档 | 旧v1 S3晚到→quarantined receipt仅对账，不自动入v2；依赖仍有效可另提adopt。归档固定最终revision，带角色/技能/策略/输入/prompt/能力/许可hash和合法资产；不带密钥/已删除正文/不可分发权重。可追溯不保证跨模型版本逐像素复现。 |

本轮合成策略/许可/预算/审批/PTS/局部重建测试与三轮审查在 `[box-local audit path]`。这是设计oracle，不是App构建、真机、模型效果、API或法律验证；发布仍需冻结模型文件/SBOM、商业审查、跨端资源/后台恢复、真实负载与用户样本验收。

- [CFG官方参数语义](https://huggingface.co/docs/diffusers/api/pipelines/stable_diffusion/text2img)
- [SnapGen-V移动视频研究，非本产品支持承诺](https://snap-research.github.io/snapgen-v/)
- [Apple内存权限，非统一4GB](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit)
- [Android内存管理](https://developer.android.com/topic/performance/memory-overview)
- [Modal冷启动与保温](https://modal.com/docs/guide/cold-start)
