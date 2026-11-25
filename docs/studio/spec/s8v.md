## 8V · 工业流程＋局部探索：逐镜执行策略

| 策略 | 前置 / 执行 / 边界 |
| --- | --- |
| still | 已批准静帧/合法素材→共享合成图持帧；适合建立空间/情绪停顿，能配音/字幕，但不叫视频模型生成。 |
| pan_zoom_2d | 单图＋确定性scale/position关键帧＋安全裁切→共享NLE/注册节点。Ken Burns是2D，不是真视差/新视角；裁切出界不擅自生成补图。 |
| layered_2_5d | 前中后景mask/soft alpha、depth或显式plane depth、被遮挡背景补全、边缘halo检查、已注册分层renderer和相机范围；图层视差才叫2.5D。缺资产报BLOCKED_LAYER_ASSETS，提议补齐或用户确认2D，不能伪装。大转角/新视角可能需重画。 |
| i2v_micro | 角色/原画版本pin、真实i2v能力、限定动作与可探索微动；参考数/时长符合具体profile。风/衣摆/呼吸也会脸手漂移。手机仅deviceProfile已验证才启用，否则可选用户自有GPU/明确授权云。 |
| full_motion | 确需走位/交互/战斗的镜头才用完整视频生成；先animatic/动作意图/连续性约束，再付候选与QA费用。不是必经升级，不承诺首尾帧/LoRA/CFG绝对锁定。 |

五种可混用、不是强制依次或固定70/30；动态漫只是Recipe之一。电影制作阶段、角色Bible、导演/视觉异构模型、PlanGraph和QA复用8B/8E/10C/10F，不另造系统。硬约束包括身份/衣着、轴线/接点、商品事实、人工锁；软偏好包括光色/情绪；探索边界只允许明确可变的次要微动/构图候选。模型输出必须审片，unknown需确认，不用“信息熵指数增长/热寂”替代指标。

| 阶段 | 命令→产物→确认/失败 |
| --- | --- |
| 规划 | Brief→Treatment/Beat/ShotSpec→角色/场景/技法pin→逐镜策略提案；Agent只读snapshot移交artifact，不直接改工程。输入分析复用hash+模型/参数缓存，不重复付费解析。 |
| 有声预演 | 台词→授权TTS或录音→实际sampleCount/sampleRate量时→占位图/字幕/音乐节拍animatic；用户确认结构/声音节奏/预算后才投重视频。未选TTS不偷偷配音，标“未配音预演”并要求补选有声阶段。 |
| 生成 | 现有PlanGraph创建analysis/asset/voice/animatic/generation/QA/NLE节点；真实capability、上传/费用/锁/revision通过才dispatch；1A许可事实按1C默认风险放行并记录assessment。QA不过最小修复，尝试/费用上限到即暂停，不无限抽卡。 |
| 成片 | Candidate只生成Proposal；手调字幕text、音量关键帧、trim/角色pin锁受保护。CAS接受→新revision→共享FFmpeg图预览/导出；保留源资产/图层/节点，不只扁平mp4。 |
| 中途变更 | 改台词只失效TTS/时码/animatic与确实依赖口型/节拍的镜头；换角色只失效引用它的镜头。plan/prompt/input/quote/rights/intent/revision变更审批重绑。已付费不可撤回部分对账、晚到隔离，不覆盖手工修改。 |
