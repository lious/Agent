## 8Q · 视频Mask追踪与背景补全：源PTS、校正与时序状态

| 路线 | 逐帧执行与边界 |
| --- | --- |
| 手机轻量辅助 | FlowAssistedMaskTracker：人工关键帧MobileSAM→OpenCV DIS/双向光流warp上一帧mask→前后向一致性/面积/边界变化QA→用传播bbox/正负点再分割。周期初值每5源帧重分割，可按运动自适应；是“光流＋周期模型细化”，不是学习式记忆。仅bbox tracker只能定位框，不产生精确mask。 |
| 桌面真memory | SAM2.1 tiny：init_state(video_path/offload flags)→add_new_points_or_box或add_new_mask→propagate_in_video，得到objectId/帧mask logits。它包含图像特征、条件帧mask、非条件memory、object pointers与temporal state，不只是bbox/上一张mask。Pack记录num_maskmem与实际配置，不假设全版本相同。 |
| 多对象与丢失 | 每对象稳定objectId，UI可显隐/改名/重新关联，不按面积排序当身份。遮挡/快速运动/镜头切换/再现→unreviewed或lost；原始IoU/logit不是跨模型概率，只用已校准Profile分数＋几何检查。lost处停止自动擦除，UI红色缺口/定位到需校正帧；不能把空mask当对象已消失。 |
| 人工关键帧 | 点选/画笔修正→新Mask版本＋correctionEpoch，锁该帧。向前/后重追仅到相邻锁定锚点或镜头边界，不能重写校正帧自身/锁tile；旧缓存依赖闭包失效，已接受NLE媒体仍保留。每边独立追踪方向，重叠区冲突供用户选，不简单平均两个身份。 |
| 源时序 | FrameMaskRef固定source blob/version、源PTS rational、decodeIndex、frameHash。VFR以解码PTS map为准，重复PTS另用decodeIndex消歧；剪辑trim不改源索引，retime通过既有TimeMap映射。2倍速在timeline .05s对应source .1s，不能floor(.05*30)取mask。光流插帧/复杂重映射若无同源mask插值能力报MASK_RETIME_INTERPOLATION_UNSUPPORTED，而非套错帧。 |
| 切镜/分块 | 切镜分析只提供候选，用户可修边界；确认切点处清memory，不跨镜继承身份。分块单位用源range＋帧清单，不用恒定fps猜时长；初始32帧core＋8帧上下文为产品策略非资源基准，SAM2条件帧/memory需求可使其扩大或缩小。只提交core，重叠输出作一致性检查，不重复入库。 |

```text
MaskTrackService.start(sourceRef,sourceRange,objectPromptRefs,profilePin): TrackJob
MaskTrackService.correct(trackId,frameKey,newMaskRef,expectedCorrectionEpoch): RetrackPlan
MaskTrackService.acceptSegment(trackId,segmentHash,reviewRef): NewTrackVersion
TrackingCheckpointState {
 pack/runtime/stateABI,objectIdMap,sourcePtsMapHash,conditioningFrameRefs,
 nonConditioningMemoryTensorRefs,objectPointerRefs,temporalPositionRefs,
 cachedFrameRange,correctionEpoch,prerollAnchorRefs,rngStateRef:null|Hash
}
// 这是Studio需实现的typed checkpoint codec，不是SAM2现成跨设备序列化API。
// 所有tensor存name/dtype/shape/byteLength/hash，拒绝不匹配/越界；不保存GPU指针/Python pickle。
// backend或stateABI不兼容：从最近已确认anchor重算；可重算上下文不重复发布core。
// 同一对象/帧/epoch只有一个原子committed chunk；部分文件不作为ready MaskAsset。

```

| 去物体路线 | 可商业化边界与实际算法 |
| --- | --- |
| 受限本地重建：static-background-anchor@1 | 适合固定机位/近似平面背景。对目标mask外特征做RANSAC单应配准→邻帧未遮挡像素warp到anchor→按有效覆盖/光度一致性鲁棒聚合，保存observedCoverageMap。仍不可见洞在单anchor由本地LaMa补一次→按已验H映射每帧，最终只在目标removeRegion合成；保留其他前景。输出哪些像素观察到、哪些AI推断，不伪称真实恢复。 |
| 受限路线失效 | 动态水面/烟火、明显视差、长遮挡、相机/光照突变可能不满足单背景模型。ReconstructionQA输出配准误差/覆盖缺口/时间闪烁供审片，超校准范围阻断自动应用；可手工补plate、缩短选区或有授权高级Profile，不能逐帧LaMa后宣称时序稳定。 |
| 授权ProPainter | 输入video f32[B,T,3,H,W]、mask[B,T,1,H,W]按Profile明确归一及holes=1。读取官方ProPainter.pth/recurrent_flow_completion.pth/raft-things.pth，各子模型授权与依赖一起审；流完成→图像/特征传播→时序Transformer补全。局部neighbor window与远参考帧按模型配置调度；只提交窗口core，overlap QA失败要求重算或人审，不简单淡化掩盖物体跳变。 |
| E2FGVI-HQ备选 | 官方E2FGVI-HQ-CVPR22.pth，NC限制如实展示但按1C默认风险放行；按其归一/flow/propagation contracts独立适配，不能套ProPainter权重ABI。官方支持任意分辨率不等于手机内存无限。 |
| 输出与音轨 | 输出VideoEraseCandidate是新视频派生资产＋MaskTrack/填充provenance；与源PTS map绑定，FFmpeg逐帧composite/encode/mux走既有6—7节。原音独立保留，不重编码声轨改变同步；精确替源前验证帧数/PTS/色彩/时长，用户锁定trim/字幕不动。 |

产品帧读取统一走共享FFmpeg SourceFrameProvider，不把原MP4再交SAM2/ProPainter独立解码后猜帧号。需实现SAM2FrameSourceAdapter.initStateFromFrames：对已固定的源帧清单按Pack resize/归一供给state.images及num_frames/原宽高，并保存index→PTS/frameHash表；它是Studio待实现适配方法，不是冒称上游已有API。参考官方init_state/propagate状态结构做固定revision适配、golden对照；RGB/设备tensor缓冲由native retain/fence管理，缺帧就暂停，不用另一个解码器悄补。极端长宽比使resize结果任一边为0时UNSUPPORTED_SOURCE_ASPECT，要求选ROI/其他路线，不静默变形。

时码命名补充：MaskAsset.frame.pts与FrameMaskRef.pts表示源资产归一presentation time，即rawPTS×timeBase−presentationOrigin；rawPTS/timeBase/原始负起点/重复PTS与decodeIndex保存在sourcePtsMap。Timeline TimeMap映射到同一归一域，不能混用原始负PTS和从0开始的sourceRange。candidate artifactHashes须含OutputManifest：actualBackend/runtimeFingerprint、输出blob/像素或sample布局、FrameGeometryMap/PTS map、剩余延迟、observed/inferred覆盖及QA/provenance；不能只存一个不可解释的文件hash。

完整本地功能分级：手机目标可做智能选区、辅助追踪、受限场景去物体；桌面提供SAM2真memory与获授权高级时序模型。当前没有已清商用许可且已验证所有手机的通用高级时序补全模型，因此该承诺明确不成立；接口、任务与授权后路径已定义，不能用云服务或经典补洞偷偷顶替。
