## 8T · 超清、画面降噪与共享推理资源

| 能力 | 具体输入输出与实现合同 |
| --- | --- |
| Real-ESRGAN图像超清 | RealESRGAN_x4plus为RRDB x4；RGB f32[1,3,H,W][0,1]→[1,3,4H,4W]。ncnn层的实际输入名/通道顺序由官方转换Pack验证，不能把OpenCV BGR直接喂RGB。倍率4不是新事实/真实纹理恢复；人脸、Logo、文字和商品划痕可能被改造，必须对比。输出2倍交付可从4倍候选确定性downsample，不能说模型本身变成x2。 |
| tile/halo | 以coreTile＋双侧halo取输入，推理后裁halo*scale，仅写不重叠core；边界按Pack padding镜像/复制策略处理，奇数宽高/窄尾块不得漏像素。初始halo32源像素仅待校准策略，不保证与整图一致；用整图golden seam误差和纹理QA决定可接受值。OOM先降coreTile保持必要halo，再CPU/排队；不能悄改倍率/模型。 |
| 画面AI降噪 | SCUNet scunet_color_real_psnr：RGB f32[1,3,H,W][0,1]，官方网络右下ReplicationPad到64倍数，输出裁回原尺寸；real_gan是另Profile，不能偷偷替换。桌面Torch基准，手机ORT静态shape候选另验；权重授权证据缺口按1C风险放行；ABI未通过仍不能启用。DnCNN灰度/固定Gaussian模型不等于真实彩色视频降噪，本轮不把未核实权重纳入默认。 |
| 经典不是AI | 当前LGPL媒体构建选择nlmeans经典降噪（源码LGPL-2.1-or-later，依赖仍审）；hqdn3d源码GPL-2.0-or-later，不能悄加进LGPL包，只有另行明确GPL合规发行/链接审查才启用。都不标AI模型；语音RNNoise、画面SCUNet和超清网络的平滑不是同一功能。 |
| 视频增强 | 逐源帧Real-ESRGAN/SCUNet→FFmpeg按原PTS map归一/编码；无memory的逐帧模型可能闪烁，不称时序超分。先小选区A/B看边缘/肤质/闪烁，用户再批整段。视频帧插值/补帧为独立能力，当前不能因为超清就自动加fps。 |
| 组合顺序 | 建议decode/color→可选轻降噪→Mask/去物体→SR→确定性字幕/Logo/颗粒/调色→encode；每一步保源空间映射与hash。过强降噪会抹纹理，SR会放大补洞伪影，顺序不是保证更好。文字水印保护可用户指定region后走经典缩放原像素覆盖；烧录文字不能保证OCR/AI完全保真。不得用于移除版权水印或规避他人权利。 |
| 几何与色彩 | 放大后newPixel=scale*oldPixel，保存FrameGeometryMap，调整像素域crop/transform/mask映射以保持NLE构图，不能只换分辨率让画面跳变；归一坐标也需源hash验证。mask可在tone-map副本分析，RGB增强不支持HDR时拒绝或明确同意SDR派生；不伪称逆tone-map恢复HDR细节。 |

```text
ImageEnhanceSpec {sourceRef,sourceRange,profilePin,scale,coreTile,halo,
 colorPolicyRef,protectedMaskRefs[],outputGeometryMapHash,expectedRevision}
EnhanceService.preview(spec,selectedRegion): DerivedCandidate
EnhanceService.render(spec): LocalJobReceipt
CapabilityProbe.inspect(packPin,device,backend): {
 available,operatorSupport[],dynamicShapeSupport,textureImportSupport,
 conformanceHash:null|Hash,calibrationHash:null|Hash,unsupportedReasons[]
}
ResourceLease {id,jobId,deviceId,backend,weightBytes,scratchBudgetBytes,
 frameCacheBytes,previewReserveBytes,deadlineClass,ownerFence,cancelEpoch}
// bytes来自manifest估算/设备校准；未知峰值不能冒充实测，应限制能力或要求校准。
// 模型metadata解析/shape验证在分配前，拒绝乘积溢出/解压炸弹/超大tensor。
NativeInferenceSession.run(inputTensorRefs,perJobRunOptions,stopToken): TensorResultRefs
// ORT可请求terminate，GPU kernel未必立刻停；直到native返回/fence完成才release输入/模型。
// C ABI handle=(slot,generation)，retain/release；模型、AVFrame、GPU纹理各自deleter。
// 回调只发进度/结果handle，Dart listener已关闭则release；不得回调已销毁UI。
// 新任务用独立RunOptions，取消一个job不能终止共用session上的别的job。

```
