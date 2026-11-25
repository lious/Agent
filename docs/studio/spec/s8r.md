## 8R · 人声分离、语音降噪与可编辑字幕

| 模块/ABI | 前后处理、结果和限制 |
| --- | --- |
| Demucs separation | FFmpeg解码→f32 stereo 44.1k→模型域[1,2,T]；htdemucs输出[1,4,2,T]，源标签按Pack固定drums/bass/other/vocals。single模型非htdemucs_ft四模型包；Transformer segment上限按官方7.8s约束，初始6s/25% overlap是产品策略。shifts=0便于一致性，不声称跨后端bit exact。 |
| 分块/电平 | 输入归一、模型逆归一采用同一受信实现；同一全局gain，不能逐stem peak-normalize。重采样保各声道同相位滤波与总sample count；模型延迟由Pack impulse校准，写残留latencySamples，补偿后为0，不能双补偿。四分轨重建残差报告能量，不许保证为0；双轨可显式选择accompaniment=original−vocals以保混合代数一致，注明含残差而非纯模型伴奏。 |
| OLA | 每chunk上下文推理后舍弃无效边，只在有效重叠输出加权；各声道同权重，out[n]=sum(w*y)/sum(w)，边界权重非0，短尾pad后按真实样本数裁剪。音频crossfade不能变成更短文件；缺块/NaN/超幅先报错，不静默补静音。 |
| RNNoise | C API rnnoise_get_frame_size()校验480@48k，输入/输出float单声道幅度按API约定16位PCM尺度（f32[-1,1]须乘32768再除回）；每10ms持续使用DenoiseState，返回VAD概率不是词级置信。不是每帧重新create。语音默认显式mono对话派生；立体声双state需同一时码并提示空间变化风险，不随意合并原音乐。 |
| DeepFilterNet3 | 48k单声道f32[1,T]音频adapter；内部ERB/STFT/复数谱状态按固定config处理。Rust/libDF或ONNX适配分别验证，不能把模型增强延迟当声卡延迟；强噪声可更自然也可能损伤辅音，用户A/B比较。 |
| 不是同一个能力 | 人声分离不等于把两个人分别分离，也不等于说话人识别；分离输出vocals可含歌声/多名说话人。缺目标speaker separation/diarization模型时明确不支持，不让模型猜姓名。降噪不去除所有混响、音乐或失真；不能默认前处理一定改善ASR。 |

```text
SeparationSpec {sourceAudioRef,range,profilePin,stems:two|four,
 preserveResidual:boolean,chunkSamples:U64,overlapSamples:U64,gainPolicy:shared,
 targetSampleRate:44100,outputFormat:f32Wav,expectedRightsEpoch}
SeparationService.run(spec): AudioCandidate{parts:StemAsset[],residualReportHash}
SpeechDenoiseSpec {sourceRef,range,profilePin,channelPolicy:monoDialogue|dualChannel,
 strengthIntent,latencyCalibrationHash,compareOriginal:true}
AudioRestoreService.denoise(spec): AudioCandidate
ASRSpec {sourceRef,range,preprocessCandidateRef:null|Id,compareOriginal:boolean,
 profilePin:whisperBase,language:null|string,vadPolicyRef,tokenTimestamps:true,
 expectedCaptionReadSetHash,lockedCueIds[]}
SubtitleService.transcribe(spec): CaptionProposal // 不是直接UPDATE字幕表
SubtitleService.accept(proposalHash,expectedRevision,lockedCueIds): CommandReceipt
// StemAsset复用8D的资产/音轨合同，原音始终独立；候选只在接受后创建NLE引用。

```

| ASR闭合 | 输入/时间/编辑合同 |
| --- | --- |
| Whisper base | 16k mono f32[-1,1]→whisper.cpp自己的PCM-to-mel，base为80 mel bands；30s窗口/29s步长沿8A复用。原音/可选分离或降噪为不同缓存键，用户先比较短样本；不用“降噪”默认覆盖原音。静音/音乐通过VAD和no-speech/重复度信号标疑，不编造台词。 |
| 词时码 | token/word时间是估计，不是精确forced alignment。窗口局部时间映射sourceTime=rangeStart+(windowStartSample+j)/16000−remainingLatencySamples/audioPartSampleRate，再通过源PTS map/NLE TimeMap对齐序列帧；latencySamples表示输出相对源的正延迟，补偿后为0，不能加错号或重补偿；边界去重同时检查重叠时段和文本，不全局去重重复词。speakerId默认null。低置信/语言混合给人校对，不冒称读心。 |
| 字幕持久化 | Cue稳定ID、源时码、ASR provenance与手改text/version分开；重识别只提新增/替换diff，锁定cue不得覆盖。接受是事务revision，撤销恢复旧cue，不销毁原转写工件。台词TTS重生导致时长变动也只提时间调整，不改手工文字。 |
| 格式首版设计 | SRT和WebVTT纯文本导入/导出：UTF-8、毫秒时间舍入与不重叠校验，转义不可信标记；ASS/SSA只受支持静态style映射并出损失报告，复杂karaoke/脚本不执行。字体和烧录仍由确定性渲染器及许可门禁处理；没有假称App已实现这些导出器。 |
