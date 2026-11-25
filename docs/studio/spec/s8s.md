## 8S · 本地文本朗读与正常授权的声音克隆

| Profile/许可 | 具体选择与能力边界 |
| --- | --- |
| Kokoro-82M v1.0 | 官方代码/权重Apache-2.0，24k mono输出；手机轻TTS默认开源候选。sherpa-onnx官方kokoro-multi-lang-v1_0示例支持中英，不能外推全语言已接通；model/voices.bin/tokens/lexicon都要pin。它选择预训练voice，不是零样本克隆。 |
| G2P许可证陷阱 | 官方示例打包espeak-ng-data，eSpeak GPL不能被Kokoro Apache遮盖；Misaki自身Apache也不替其可选GPL依赖授权。闭源手机不直接照搬该包：实现经审许可的中英词典＋数字规范化/音素映射frontend（如MIT pypinyin/jieba来源另审），未知词/多音字允许人工发音覆盖或明确OS离线voice降级。完整sherpa/eSpeak路线的发行许可缺口按1C风险放行，技术ABI/依赖安全仍另验，不声称进程分离自动免GPL。 |
| Kokoro图ABI | 逻辑输入int64[1,L]音素token(含边界)、float[1,256] style、float[1] speed→float波形[1,N]/[N]按实际导出ABI；style按音素长度选voices条目，L和style_dim来自Pack metadata，不硬裁长文本。native输入名/输出shape必须实际inspect；语言/字典/tokens不匹配报PHONEME_UNSUPPORTED。手机资源/音质未测。 |
| CosyVoice2-0.5B | 代码与官方HF卡Apache-2.0；默认授权零样本克隆桌面本地目标，sample_rate=24000来自官方yaml。参考语音prompt_speech_16k＋准确prompt_text、目标text→speaker embedding/speech tokens/LLM→flow→HiFT 24k波形。内部各tokenizer/embedding/codec/normalizer依赖分别入SBOM，不只看顶层许可。 |
| CosyVoice3/OpenVoice | Fun-CosyVoice3-0.5B-2512官方卡Apache-2.0，另Profile验收不替换2的ABI。OpenVoiceV2 MIT可作为TTS基础声→tone-color conversion→目标声，参考/输出SR从converter已验config读取并显式resample，不硬套24k。VAD/embedding/source TTS和MeloTTS等依赖均独立审。 |
| 不默认选F5/Piper | F5-TTS代码MIT但官方预训练weights CC-BY-NC，商业授权缺口默认风险放行并保留NC事实；另获授权/合规自训可更新事实；Piper当前OHF engine GPL-3.0-or-later，项目明确不替voice模型授权，声库MODEL_CARD/训练来源链各审。不能用旧MIT仓库或笼统“开源”掩盖当前分发义务。 |

```text
SpeechService.prepareText(text,language,normalizerPin,pronunciationOverrides): SentencePlan
SpeechService.validateVoice(voiceBindingId,usage,liveRightsEpoch): VoiceGateReport
SpeechService.synthesize(dialoguePlanHash,lineIds,expectedRevision): AudioJobReceipt
SpeechService.registerAuthorizedReference(sourceRef,voiceRightsId,scope): PrivateVoiceReference
SpeechService.revokeReference(referenceId,expectedRightsEpoch): RevocationReceipt

SentencePlan {scriptHash,unicodeScalarOffsets[],sentences[],normalizedReadings[],
 languageSpans[],phonemeTokens[],warnings[],frontendFingerprint}
// 默认按句号/问叹/语义停顿拆句，超token上限按合法音素边界再拆；不截断台词。
// 数字/价格/缩写先显示朗读展开供用户改；sourceOffset/length按Unicode scalar，非UTF-16字节。
VoiceGateReport {rightsRecordId,subjectId,allowedUse,expiry,revocationEpoch,
 referenceSourceHash,modelCompatibilityHash,referenceVADReport,unresolved[]}
// CosyVoice参考目标3..15s净有声为产品初始策略，非上游保证；具体Profile可更严格。
// VAD去长静音但保自然停顿，拒绝无声/多说话人混录不明/削波严重；净时长和原时码都留。
// prompt_text必须对应参考语音；可本地ASR建议后用户确认，不能当已知正确转写。
// speed仅在该Profile真实支持时是硬参数；emotion/style通常软建议，不杜撰接口。

```

| 权利/交互/后处理 | 可编码规则 |
| --- | --- |
| 正常克隆 | 支持本人或确有授权的真人声音；不是一刀切禁止。VoiceRightsRecord复用现有RightsRecord，额外记录subject、reference、使用范围/期限、商业许可、撤销epoch。未知授权提示补确认，不把用户勾选字段当第三方许可证明。拒绝欺诈冒充/绕过身份验证等用途；普通创作授权按范围正常执行。 |
| 隐私 | reference audio与voice embedding是敏感派生资产，私有VoiceStore加密，key用平台安全存储；不写可移植Project/CharacterPack正文。VoiceProfile保description/sample refs/cloningAllowed/voiceRightsId，私有binding sidecar按profile hash关联；跨App显式授权或重新导入，不共享密钥。撤销阻断新任务、使embedding/缓存失效并取消未完成，已付费远端删除不能保证；本地擦除不承诺SSD取证级销毁。 |
| 声音界面 | 角色@Voice选择预置朗读或授权克隆→显示语言/参考净时长/本地模型→试听短句→逐句候选→接受独立音轨。style/速度/读音可改，用户锁定字幕/音量不变；台词改字仅该句音频及依赖口型失效，视觉镜头不无故重做。 |
| 拼接与时间 | 各句实际sample count为权威，不按字数假定秒数；按句边界留静音/短crossfade只在无辅音被切断时提议，不能重复发声。输出24k先保无损原候选，再libswresample→48k工程音轨，精确sample offset；limiter/响度是确定性独立提案。时长放不下提示改速/缩文/延长，不偷偷时伸锁定对白。 |
| 独立合同 | 新增DialoguePlan定义tts/clone，不改闭合VerticalBrief.voiceMode枚举；旧voiceMode仅provider原生音轨策略，本地朗读不伪装nativeTrial/uploadedAudio。生成音频接受后是现有独立audio Asset/Clip。TTS不是唱歌，音色克隆不保证口型，lip-sync没有已验Profile时明确独立未支持。 |
