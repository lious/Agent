# ADR0021 — 一个真实静态 opacity 消费者，而不是完整 EffectRegistry / GPU RenderGraph

## 合同与边界

保留原 s4/s4a、I-008、I-022、V-003 全验收和硬依赖。此切片只实现单视频轨、相同偶数尺寸≤2048、1× CFR、Rec709 limited YUV420、黑色不透明项目背景上的一个静态 clip opacity（pluginVersion1.0.0）。不是 GPU/多轨/关键帧/转场/任意资源支持。未知或不可执行 effect、字体、mask、imageDocument、library、LUT、retained 等继续 opaque 保全只读并拒绝执行，不移除语义换可写。

## 实现

- 用户显式设置有限实数[0,1]。effect/clip/sequence 生成不可变版本；相同值不改文档；普通 undo 沿用事务历史。split 为新 clip 克隆 effect ID/owner；delete 仅移除当前 snapshot 的孤立节点，历史 SQL/pins 不删。抽取音频不复制视觉 effect，linked split 仍原子处理。
- 项目保存完整 scalar；已注册 CPU recipe 编译成 Q16 整数0..65536（最近取整）。无 keyframe/extension，严格匹配 pluginVersion/owner/type；不接受额外未知效果。旧 native adapter 没有 linearOpacityV1 时 SDK 明确拒绝，JSON recipe 仍闭合校验。
- C++/FFmpeg 同一真实函数：limited BT709 YUV420 → full-range RGB8 → BT709 逆 transfer → FP32 linear×opacity（黑背景上的 premultiplication）→正 transfer/RGB8 → limited YUV420。Identity 保留旧直接路径避免额外量化。不能称全浮点流水线：RGB staging 是8bit；与原 FP16 GPU 路线的差异明确保留，尚未取得 GPU 等价资格。
- 静态和 AudioSink 已确认时钟选择的预览均对**原件全尺寸**执行同一节点/YUV420转换，再缩成≤128显示；不能直接乘预缩小 RGBA 或烘焙 source proxy 冒充同图。最终 export 也从原件执行，不截图 Flutter，不用 FFmpeg CLI 构造生产时间线。
- native 可显式捕获最多4个唯一 frame index 的实际 encoder-input YUV420，经显示转换得到的 RGBA，callback 在 avcodec_send_frame **之前**。正常 export 不捕获。样本字段 stage=actual-yuv420-before-encoder；大尺寸样本为显示缩图，不是全分辨率全片/GPU资格。本次128×72灰块样本无需缩放，与独立 BT709 transfer 数学参考≤2/255比较；实际320×180彩色视频两个点比较的是128×72显示样本。
- 输出帧复用前 av_frame_make_writable 触发 encoder 引用安全的 COW；临时 RGB/SWS/AVFrame RAII；每32行取消检查，最终转换后/编码提交前再次检查。捕获和资格数量有限，不添加数据库表/注册存储协议/云 API。
- 可写资源采纳在既有来源/hash/stream/预算/lease/revision/fence验证之外，实际调用 native 消费每个不同 asset+opacity（上限64）后才发布 fork，不能只相信闭包/能力布尔值。已有归档/fork/ImportMap负责重映射 clip/effect owner。

## 可复跑验证和未完成

见 implementation/evidence/static-opacity/commands.json 与 summary.json（精确冻结 source/library hash）。真实 Flutter/native 点击设置、静态预览、undo、ZIP 保存、fork恢复、MP4导出；SDK 关闭重开、资源采纳、预览/实际编码输入比较；独立灰块 linear-light reference；原 source seek、保存/迁移/安全回归各自列出。测试 CLI 只生成隔离自有 fixture，不是生产媒体实现。

原 I-008 尚缺完整 registry、变换/关键帧/转场 handles/连续性及 I-005；I-022 尚缺完整 GPU/texture lease/100次 frame-leak 取消及上游资格。V-003 不因局部灰块/显示样本变为整项完成。原 schema9 无法强制阻止旧 executable 共写；必须使用已更新 writer。真实 resume underrun 未解决；软件服务时钟预览不等于物理 AV 呈现同步或稳定实时帧率。Web/native RTC 网络策略受阻不重测、不绕过；本批无新物理多设备或非 Linux 资格。
