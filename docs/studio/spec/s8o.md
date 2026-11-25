## 8O · 本地AI模型与运行时：选择落定，发布能力不造假

| 能力/Profile | 官方代码与权重证据/选择 | 设备边界 |
| --- | --- | --- |
| 智能Mask：mobilesam-vit-t@1.0.0 | ChaoningZhang/MobileSAM的vit_t与官方weights/mobile_sam.pt；仓库Apache-2.0，权重来源及授权判读随Pack归档。默认轻量点/框路线。官方ONNX脚本导出decoder，不证明整条TinyViT encoder/decoder已能手机运行。EfficientSAM vit_t/vit_s为Apache-2.0备选，不按名称推断性能。 | 手机ORT CPU整图目标，CoreML/Android EP另验；本轮未转换/实机。模型缺失时只保留明确的手工画笔，不能声称智能模型已启用。 |
| 记忆追踪：sam2.1-hiera-tiny@1.0.0 | facebookresearch/sam2，sam2.1_hiera_tiny.pt；官方明确code/checkpoints Apache-2.0。SAM3采用独立SAM License，不继承SAM2许可，当前不作默认。 | 桌面真正memory propagation主目标；手机SAM2转换是进阶待验。手机首版轻量辅助路线见8Q，不冒充SAM2记忆网络。 |
| 抠图：birefnet-general@1.0.0 | ZhengPeng7/BiRefNet仓库和官方HF卡均MIT；高分辨率前景概率/细边候选，不是补背景，不保证透明材质物理alpha。 | 桌面Torch基准；手机lite/ONNX量化需独立Pack与细边对照，不拿第三方量化文件当同模型。 |
| 智能图像擦除：lama-big@1.0.0 | advimman/lama项目Apache-2.0；目标big-lama/last.ckpt。官方README未单独明确checkpoint授权范围，商业权重授权范围未明保留unknown；按1C默认允许构建/用户选定的收集打包并警告，不标已获授权。OpenCV Telea/NS只是小洞经典算法，不替代本地智能擦除主路线。 | 桌面本地Torch；手机固定ROI＋FFT适配/ORT CPU目标见8P，未构建验证。缺商业许可仅warning，ABI不支持仍阻断；二者都不静默转云。 |
| 高级视频补全 | ProPainter官方S-Lab License限非商用默认；E2FGVI为CC-BY-NC4.0。商业App内置/托管缺授权记录COMMERCIAL_LICENSE_REQUIRED warning，按1C默认执行；真实授权凭证仍按版本/用途核验，不伪造。 | 技术适配就绪后优先桌面本地重流程，商业许可缺口不改变执行默认；不承诺手机任意场景高级补全。近静态背景重建＋一次LaMa补洞另列受限路线。 |
| 人声分离：demucs-htdemucs@1.0.0 | facebookresearch/demucs v4/htdemucs官方模型来源与MIT项目证据绑定。UVR是工具/模型集合；BS-RoFormer实现如lucidrains为MIT，但第三方checkpoint许可另审，不能继承代码MIT。 | 桌面Torch worker首选；手机ORT/ExecuTorch移植须过complex/STFT/Transformer与资源gate，非已交付能力。允许通过设备校准后的本地慢任务，不宣称实时。 |
| 语音降噪 | RNNoise官方C实现BSD-3-Clause，绑定内置weights源码/模型blob来源；DeepFilterNet README明确code和weights可选MIT或Apache-2.0。手机默认RNNoise，DeepFilterNet3为进阶增强。 | 本地CPU，48k语音链；不写未测RAM/时延，不把音乐分离当降噪。 |
| ASR/超清 | Whisper base多语权重＋whisper.cpp，代码/权重MIT证据分列。RealESRGAN_x4plus官方模型/项目BSD-3-Clause，ncnn BSD-3-Clause，走官方Real-ESRGAN-ncnn-vulkan转换路线；SCUNet color_real_psnr为Apache-2.0项目的画面AI降噪候选。 | Whisper手机/桌面各后端待测；SR图片ncnn CPU/Vulkan目标，视频逐帧有闪烁风险。iOS CPU、MoltenVK另验，不宣称ncnn直接Metal零拷贝。 |
| 朗读/授权克隆 | Kokoro-82M v1.0 Apache-2.0为轻TTS默认候选；CosyVoice2-0.5B代码/官方卡Apache-2.0为零样本克隆桌面主目标；CosyVoice3-0.5B-2512独立候选。OpenVoiceV2代码/权重MIT，是声色转换链而非一体TTS。 | 8S细化。手机Kokoro需音素/依赖/资源gate；未通过可显式用OS已下载离线voice。高质量克隆手机端是进阶待验，不用桌面例程证明手机可跑。 |

@1.0.0是Studio适配合同版本，不是伪造上游版本。ModelPack构建必须填写真实sourceRevision、文件sha256、tensor/operator fingerprint并通过完整性/ABI；商业许可证据缺项显式unknown/missing，按1C风险放行，不编造许可。Qwen-Image-Edit/Draw Things属于生成编辑另一条路线，具体qwen_image_edit_2511_q6p在iPhone离线运行仍未证实，不能替代轻量Mask/追踪/补洞；AnimeGANv2也不因代码可读而视为无条件商用。

```text
packages/studio_ondevice/ // 纯Dart DTO/图/权限/候选；Dart不做实时像素与FFT
  pipeline_compiler.dart, mask_coordinator.dart, audio_restore_coordinator.dart
  speech_coordinator.dart, candidate_apply_coordinator.dart
native/studio_inference/ // C++ tensor/AVFrame/resource lease/ORT/ncnn/whisper/RNNoise
  model_pack_loader.{h,cc}, frame_tensor_adapter.{h,cc}, checkpoint_codec.{h,cc}
  ffc_fft_adapter.{h,cc} // 手机LaMa目标，尚未构建，不是已存在插件
workers/studio_torch_local/ // 桌面本地隔离进程；固定签名架构，无任意remote code

OnDevicePipelineCompiler.validate(pins,capabilities,sourceProbes,liveRights): GateReport
OnDevicePipelineCompiler.compile(taskSpec,namespace,expectedRevision): PipelineSnapshot
ModelPackManager.planInstall(packId,catalogVersion): DownloadPlan
ModelPackManager.verify(staging,signature,sha256,licenseEvidence,quota): VerifiedPack
ModelPackManager.acquire(pin,backend,resourceLease): ModelHandle
ModelPackManager.release(handle,fence): void // in-flight native refs=0后才能热卸载
PipelineExecutor.submit(graphHash,revision,cancelEpoch): JobReceipt
PipelineExecutor.suspend(jobId,reason): CheckpointReceipt
PipelineExecutor.resume(checkpointHash,currentEpochs,deviceCapabilities): ResumePlan
PipelineExecutor.cancel(jobId,expectedRecordVersion): CancelReceipt
LocalCandidateApply.preview(candidateId,targetRevision): Diff
LocalCandidateApply.accept(diffHash,expectedRevision,manualLocks): ExistingCommandReceipt
// ModelPack拒绝不可信pickle/YAML !new/trust_remote_code。上游研究配置由构建器
// 转为固定schema/已编译架构；应用不能eval LaMa/CosyVoice的任意YAML或执行包内脚本。

```

| 执行规则 | 实现边界 |
| --- | --- |
| 缓存/共享 | key=H(namespace,source blob/frame/range/PTS map,geometry/color policy,pack/runtime,parameters,prompt/correction版本,privacy/rights epoch)。同ACL不可变artifact可供不同Agent模型引用；相同hash不是跨App读私有素材的许可。 |
| 本地不联网 | Pipeline.offlineOnly=true、allowCloudFallback=false。推理无网络凭据，上传走独立图与Broker审批；桌面worker可OS sandbox禁网。手机进程内native不能天然逐模块OS禁网，须审包/禁网络接口/飞行模式和抓包测试，不虚称线程级硬隔离。 |
| 资源 | 先保实时预览/音频时钟，再给weights/scratch/decoded frame/cache配lease；重模型默认单驻留，可并驻轻模型须校准。内存告警/导出优先停新推理→checkpoint→释放tensor→卸载；不以云回退绕过预算。 |
| 各端 | ORT CPU作基准；CoreML/Android EP可能分图和额外拷贝，须逐算子探测。ncnn Vulkan/Apple Metal/CUDA桥接不同。Web单列WASM/WebGPU，不宣称移动二进制通用；后台任务不保证持续运行，恢复见8U。 |
