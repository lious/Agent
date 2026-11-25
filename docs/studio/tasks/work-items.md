# 完整任务合同：以最新Page为准

全部planned/unvalidated，拟议路径未经实际仓库验证。

## V-001 · 冻结首个原生端与工具链探针

### id

V-001

### title

冻结首个原生端与工具链探针

### phase

A

### spec

- 6a
- 6b
- 6d
- 12

### hardDeps



### gates



### scope

含P0及跨端构建资格；不含正式App功能。

### steps

选现有/借测P0→最小Flutter+C ABI探针→逐OS登记构建/启动。

### deliverable

ToolchainProfile、ABI清单、可复跑探针和失败报告。

### acceptance

每目标3次干净构建/启动；2个namespace句柄不串用；无工具机型记unvalidated，不代填成功。

### profile

BUILD：已有开发机；SDK/编译工具未来安装另确认，无需购买设备。

### decision

P0通过→I-001/I-015；其他端失败只延后本端。

### effort

2–4人日/首端，其他端每端1–2人日估计

### paths

tools/spikes/toolchain/；tests/acceptance/v001/

### kind

V

### status

unvalidated

### rowOrder

1

### entryFile

tools/spikes/toolchain/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v001.py

### acceptanceCommand

python tools/spikes/toolchain/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-001.json

### singlePersonPriority

1 首组

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-001@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-002 · FFmpeg构建与codec真实probe

### id

V-002

### title

FFmpeg构建与codec真实probe

### phase

A

### spec

- 6
- 6c
- 7
- 7a
- 7b

### hardDeps

- V-001

### gates



### scope

含9.1配置/硬件帧/软件路径；不含全格式保证。

### steps

固定源码与配置→探测codec→目标样本decode/encode/mux→取消释放。

### deliverable

NativeCodecProfile、SBOM、格式方向矩阵及sample hash。

### acceptance

P0处理MP4/H264 Main L4.0 8bit420 1080p30/AAC48k；10次取消无活句柄；不支持格式100%明确reason。

### profile

MEDIA：P0真机/桌面及公开自拟媒体；编译工具，无付费API。

### decision

失败→换已验同格式路径或缩小支持；无encoder则不开放导出；I-015至I-024消费。

### effort

3–5人日/首端估计

### paths

native/spikes/codec_probe/；tests/media/codec/

### kind

V

### status

unvalidated

### rowOrder

2

### entryFile

native/spikes/codec_probe/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v002.py

### acceptanceCommand

python native/spikes/codec_probe/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-002.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-002@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-003 · PTS/色彩/CPU-GPU参考图一致性

### id

V-003

### title

PTS/色彩/CPU-GPU参考图一致性

### phase

A

### spec

- 2
- 4
- 7
- 7a

### hardDeps

- V-002

### gates



### scope

含有理PTS和SDR参考；不含HDR承诺。

### steps

造非零PTS/VFR/旋转样本→seek/合成→比CPU与GPU→核输出时长。

### deliverable

MediaGoldenProfile与差异报告。

### acceptance

60秒视频时长误差≤1交付帧；20点seek误差≤1帧；SDR测试patch最大差≤2/255；失败不能只肉眼放行。

### profile

MEDIA：P0 GPU，1080p30与720p代理，记录OS/driver/build。

### decision

超差定位矩阵/采样/取整后复测；I-022/I-024只开放已过组合。

### effort

3–5人日估计

### paths

tools/spikes/render_goldens/；tests/media/pts_color/

### kind

V

### status

unvalidated

### rowOrder

3

### entryFile

tools/spikes/render_goldens/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v003.py

### acceptanceCommand

python tools/spikes/render_goldens/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-003.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-003@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-004 · seek、音频时钟与热/背压负载

### id

V-004

### title

seek、音频时钟与热/背压负载

### phase

A

### spec

- 6c
- 6d
- 7
- 7a

### hardDeps

- V-002

### gates



### scope

含真实设备clock/drop/backpressure；不把吞帧隐藏成成功。

### steps

60秒3视频轨2音轨→20次seek→20分钟热负载→后台/设备失联。

### deliverable

ClockBudgetProfile、延迟/内存/thermal分布与队列上界。

### acceptance

音画偏差≤20ms；音频无持续underrun；队列不超配置上界；无OOM/死锁。预览drop率目标≤5%，未达只降预览代理并披露。

### profile

MEDIA：P0＋最老候选手机，冷3次/稳态10次；不要求先买机。

### decision

失败→限并发/代理/修clock；不能改输出时间；I-021/I-023消费。

### effort

3–5人日/首类设备估计

### paths

tools/spikes/clock_load/；tests/media/clock/

### kind

V

### status

unvalidated

### rowOrder

4

### entryFile

tools/spikes/clock_load/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v004.py

### acceptanceCommand

python tools/spikes/clock_load/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-004.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-004@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-005 · StoragePort落盘与非原子provider故障

### id

V-005

### title

StoragePort落盘与非原子provider故障

### phase

A

### spec

- 5
- 5a
- 5b
- 5c
- 5d
- 5e

### hardDeps

- V-001

### gates



### scope

含本地fsync与SAF/iCloud分开证明；不把rename套所有云盘。

### steps

每提交阶段杀进程/ENOSPC→重启校验→外接盘撤销→provider staging替换。

### deliverable

DurabilityProfile、崩溃点日志、唯一好副本证明。

### acceptance

每崩溃点10次；durableRevision零丢失、校验失败零静默打开、取消不覆盖好副本；未测provider保持受限。

### profile

STORAGE：临时合成工程/现有或借测外盘，禁止用户工程。

### decision

本地不通过先修协议；provider非原子→staging+确认替换；I-011/I-014按端准入。

### effort

3–5人日/本地，provider另1–3人日估计

### paths

tools/spikes/storage_faults/；tests/storage/faults/

### kind

V

### status

unvalidated

### rowOrder

5

### entryFile

tools/spikes/storage_faults/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v005.py

### acceptanceCommand

python tools/spikes/storage_faults/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-005.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-005@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-006 · HDR/LUT/高级调色选型与门禁

### id

V-006

### title

HDR/LUT/高级调色选型与门禁

### phase

E

### spec

- 4
- 4b
- 6c
- 7a

### hardDeps

- V-003

### gates



### scope

含色彩合同ADR与参考渲染；不含未测HDR发布。

### steps

锁EOTF/色域/tonemap→32个合成patch→HDR显示与导出对照→冻结LUT格式。

### deliverable

ColorPipelineADR及可用/延期组合。

### acceptance

线性参考CPU/GPU归一误差目标≤0.002；metadata/范围100%保留；无HDR显示器只验证数值，不声称观感合格。

### profile

HDR：可借HDR屏/目标GPU；借不到不采购。

### decision

通过才启I-059对应HDR/高级grade；失败保SDR与原件，不静默tonemap。

### effort

3–5人日估计

### paths

tools/spikes/hdr/；tests/color/advanced/

### kind

V

### status

unvalidated

### rowOrder

6

### entryFile

tools/spikes/hdr/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v006.py

### acceptanceCommand

python tools/spikes/hdr/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-006.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-006@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-007 · Web demux/mux库与浏览器资格

### id

V-007

### title

Web demux/mux库与浏览器资格

### phase

E

### spec

- 6
- 6a
- 7
- 7b

### hardDeps

- V-001

### gates



### scope

含两候选库API/版本/许可事实与WebCodecs；不导入native FFmpeg假通用。

### steps

选两库→MP4/H264/AAC roundtrip→Worker/OPFS/取消→浏览器矩阵。

### deliverable

WebLibraryADR、锁文件候选与feature矩阵。

### acceptance

Chrome/Edge各10个60秒样本无时长漂移>1帧；配额/无codec时明确拒绝；Safari/Firefox未过只开已验feature。

### profile

WEB：现有桌面浏览器；secure context及隔离header本地测试，无服务开通。

### decision

失败→Web保会话/图片或只读；I-020不硬阻原生交付。

### effort

3–5人日估计

### paths

tools/spikes/web_media/；tests/web/codec_storage/

### kind

V

### status

unvalidated

### rowOrder

7

### entryFile

tools/spikes/web_media/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v007.py

### acceptanceCommand

python tools/spikes/web_media/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-007.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-007@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-008 · Qwen量化与小模型工具效果

### id

V-008

### title

Qwen量化与小模型工具效果

### phase

B

### spec

- 6b
- 10
- 10b
- 12a

### hardDeps

- V-001

### gates



### scope

含Q4目标/Q8对照与第二异构文本模型同集资格；不以JSON能parse代替目标完成。

### steps

冻结权重/量化/runtime→100条工具指令含held-out→冷热/注入/截断/取消。

### deliverable

LLMProfile与逐样本结果、内存/KV报告。

### acceptance

端到端目标完成率≥90%；越权执行=0；参数非法不执行=100%；4096总ctx含1024输出。首token p95≤10s为待测目标，未达须显式降档。

### profile

SMALL-AI：8GB级候选手机或16GB桌面；第二本地模型另pin，若用云文本Profile须另批费用/上传；未来下载另确认。

### decision

不达→缩工具/改模板/更小已验包；不得静默云；I-030/I-034消费。

### effort

3–5人日/首包估计

### paths

tools/spikes/llm_tools/；tests/fixtures/agent100/

### kind

V

### status

unvalidated

### rowOrder

8

### entryFile

tools/spikes/llm_tools/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v008.py

### acceptanceCommand

python tools/spikes/llm_tools/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-008.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-008@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-009 · Whisper字幕质量与时间定位

### id

V-009

### title

Whisper字幕质量与时间定位

### phase

C

### spec

- 8a
- 8r
- 12a

### hardDeps

- V-001

### gates



### scope

含base多语/VAD/手改保护负载；不含说话人身份识别。

### steps

5分钟中英净音+噪音/音乐→30秒分窗→人工真值对齐→冷热测量。

### deliverable

ASRProfile、CER/WER/词时码/RTF和失败样本。

### acceptance

净音CER/WER目标≤20%；已对齐词时码中位误差≤200ms；静音/音乐20段无直接自动接受的幻觉；噪声分组单列。

### profile

SMALL-AI：P0手机/桌面，16k mono；素材为合成/获权公开语音。

### decision

不达→限制语言/提示人工审校；保原音，不强制分离；I-046消费。

### effort

2–4人日/语言组估计

### paths

tools/spikes/asr/；tests/audio/asr_gold/

### kind

V

### status

unvalidated

### rowOrder

9

### entryFile

tools/spikes/asr/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v009.py

### acceptanceCommand

python tools/spikes/asr/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-009.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-009@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-010 · 分离/降噪模型与相位延迟验证

### id

V-010

### title

分离/降噪模型与相位延迟验证

### phase

C

### spec

- 8o
- 8r

### hardDeps

- V-001

### gates



### scope

RNNoise、DeepFilterNet3、htdemucs分别Profile；不宣称所有手机分离实时。

### steps

已知stems合成混音→分块/OLA→延迟补偿→原音盲听与峰值统计。

### deliverable

每包资源/质量矩阵与残差资产合同。

### acceptance

已知混音SI-SDR改善目标≥3dB；输出无NaN/clip；含residual重建相对RMS误差≤1e-5；10段语音主观中位≥3.5/5。

### profile

AUDIO：RNNoise手机CPU；分离先桌面16/32GB，GPU可选。

### decision

分别go/no-go；不因重分离失败禁轻降噪；I-047消费。

### effort

3–5人日/首组合估计

### paths

tools/spikes/audio_restore/；tests/audio/ola_phase/

### kind

V

### status

unvalidated

### rowOrder

10

### entryFile

tools/spikes/audio_restore/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v010.py

### acceptanceCommand

python tools/spikes/audio_restore/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-010.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-010@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-011 · 本地完整mask与图像智能填充资格

### id

V-011

### title

本地完整mask与图像智能填充资格

### phase

C

### spec

- 8o
- 8p
- 8u

### hardDeps

- V-001

### gates



### scope

含MobileSAM encoder+decoder、BiRefNet可选、LaMa ROI；不把抠图当补背景。

### steps

完整导出/张量检查→20图点框/负点/方向映射→mask边缘→本地填充。

### deliverable

MaskEraseProfile、转换hash、IoU/人评/资源记录。

### acceptance

可见对象mask IoU中位目标≥0.85；人工锁区像素变化=0；填充审片中位≥3.5/5；所有处理网络调用=0。

### profile

IMAGE-AI：8/12GB候选手机与桌面；512 ROI，公开获权图，未来模型下载另确认。

### decision

不达→标待适配、保手工mask；经典补洞仅明确替代；I-043消费。

### effort

4–6人日/首完整链估计

### paths

tools/spikes/local_erase/；tests/image/mask_geometry/

### kind

V

### status

unvalidated

### rowOrder

11

### entryFile

tools/spikes/local_erase/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v011.py

### acceptanceCommand

python tools/spikes/local_erase/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-011.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-011@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-012 · 本地视频mask传播与时序补全

### id

V-012

### title

本地视频mask传播与时序补全

### phase

D

### spec

- 8q
- 8u
- 6b

### hardDeps

- V-011

### gates



### scope

分别验证flow+refine、SAM2 memory、temporal inpaint；不把bbox或逐帧LaMa说成稳定修复。

### steps

10段5秒720p含遮挡/切镜/VFR→人工mask关键帧→分块checkpoint→审片。

### deliverable

TrackProfile与EraseProfile分别出结论。

### acceptance

可见标注帧IoU中位目标≥0.75、身份切换=0；时序补全人评≥3.5/5；切镜不传播、锁mask不改；未过高级补全明确no-go。

### profile

TRACK：手机轻路线；桌面32GB/8–12GB VRAM候选，模型特定；无硬件不租用。

### decision

追踪通过可单独上线；补全不通过仍待适配/授权资源可选，不以许可缺口本身阻执行；I-044/I-045分别消费。

### effort

4–6人日/路线估计

### paths

tools/spikes/video_erase/；tests/video/track_pts/

### kind

V

### status

unvalidated

### rowOrder

12

### entryFile

tools/spikes/video_erase/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v012.py

### acceptanceCommand

python tools/spikes/video_erase/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-012.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-012@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-013 · 超清/图像降噪分块与视频闪烁

### id

V-013

### title

超清/图像降噪分块与视频闪烁

### phase

C

### spec

- 8t
- 8u
- 4b

### hardDeps

- V-003

### gates



### scope

含RealESRGAN/ncnn和SCUNet；不将倍率等于新真实细节。

### steps

1024源图tile/halo→图边接缝→10段静止/运动视频→OCR/水印保留。

### deliverable

RestoreImageProfile、边界误差/资源/闪烁报告。

### acceptance

合成tile接缝目标≤2/255；静止patch帧间归一RMS目标≤0.03；文字/水印不得无提示替换；失败帧候选不能自动应用。

### profile

IMAGE-AI：手机小图与桌面GPU；视频先短选区，4x面积16倍纳入存储。

### decision

图片go不等于视频go；失败调tile/模型或仅图片开放；I-048消费。

### effort

3–5人日估计

### paths

tools/spikes/upscale/；tests/image/tile_video/

### kind

V

### status

unvalidated

### rowOrder

13

### entryFile

tools/spikes/upscale/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v013.py

### acceptanceCommand

python tools/spikes/upscale/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-013.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-013@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-014 · Kokoro/OS离线TTS前端与音质

### id

V-014

### title

Kokoro/OS离线TTS前端与音质

### phase

C

### spec

- 8s
- 6b

### hardDeps

- V-001

### gates



### scope

含G2P/字典/音素/24k输出；不含克隆或唱歌。

### steps

中英各10句/数字多音字→音素→流式句段→离线voice验证与盲听。

### deliverable

TTSProfile与frontend依赖锁、发音覆盖表。

### acceptance

净文本回识别CER目标≤10%且人工可懂度中位≥4/5；拼接无NaN/clip；未知音素明确报错；离线网络请求=0。

### profile

VOICE：8GB候选手机/桌面；OS voice需已下载；GPL等许可事实只警告不隐性阻断。

### decision

失败→用户选择已验证OS离线声线/改发音；I-049消费。

### effort

2–4人日/语言组估计

### paths

tools/spikes/tts/；tests/audio/phoneme_join/

### kind

V

### status

unvalidated

### rowOrder

14

### entryFile

tools/spikes/tts/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v014.py

### acceptanceCommand

python tools/spikes/tts/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-014.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-014@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-015 · 授权克隆端到端与隐私撤销

### id

V-015

### title

授权克隆端到端与隐私撤销

### phase

D

### spec

- 8s
- 8e
- 1c

### hardDeps

- V-014

### gates



### scope

CosyVoice2桌面目标/OpenVoice可选；不声称手机零样本克隆现成。

### steps

获权参考VAD净音→embedding/tokens→8句目标台词→同意撤销/中断恢复。

### deliverable

CloneProfile、引用声纹加密/清除证据与听感表。

### acceptance

可懂度/主观相似度中位目标≥3.5/5；未授权/已撤销输入执行=0；撤销后新生成与缓存命中=0；不得日志泄embedding。

### profile

VOICE-GPU：32GB主存/8–12GB VRAM候选；只用获权公开/自拟测试，不取用户私音。

### decision

质量失败→克隆能力待适配，普通TTS继续；I-050消费。

### effort

3–5人日/首包估计

### paths

tools/spikes/voice_clone/；tests/privacy/voice_revoke/

### kind

V

### status

unvalidated

### rowOrder

15

### entryFile

tools/spikes/voice_clone/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v015.py

### acceptanceCommand

python tools/spikes/voice_clone/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-015.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-015@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-016 · ACE-Step1.5音乐主Profile

### id

V-016

### title

ACE-Step1.5音乐主Profile

### phase

D

### spec

- 8d
- 6b
- 1b
- 1c

### hardDeps

- V-001

### gates



### scope

含所选turbo+LM组合；不采官方宣传速度为SLA。

### steps

锁组合→8个15秒纯乐/歌词brief→音频QC/节拍→冷热与取消。

### deliverable

ACE资源/音质/能力报告及MusicCapability。

### acceptance

8段中≥6段审听≥3.5/5；NaN/损坏输出=0；仅BPM合适样本目标误差≤5%，未达标为软建议；花费不超批准上限。

### profile

MUSIC：自有32GB/8–12GB GPU候选；无GPU则待验，不自动云。

### decision

通过启I-041的ACE子能力；失败重选组合/明确候选需人工，不牵连其他音乐Profile。

### effort

3–5人日估计

### paths

tools/spikes/ace/；tests/music/ace_fixture/

### kind

V

### status

unvalidated

### rowOrder

16

### entryFile

tools/spikes/ace/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v016.py

### acceptanceCommand

python tools/spikes/ace/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-016.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-016@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-017 · Stable Audio Small离线短SFX/loop

### id

V-017

### title

Stable Audio Small离线短SFX/loop

### phase

D

### spec

- 8d
- 6b
- 1c

### hardDeps

- V-001

### gates



### scope

含Arm包reference runtime/算子；不将Arm等于所有iOS。

### steps

核包ABI→4个≤11秒SFX/loop→CPU推理→离线/热/取消测量。

### deliverable

SAOProfile与LiteRT版本/依赖证据。

### acceptance

4种用途至少3种人评≥3.5/5；44.1k stereo/时长合法100%；无网络、无OOM；无法完整导出则保持实验。

### profile

MUSIC-MOBILE：8GB Android候选；iOS另配实例，未测不冒领。

### decision

通过只启I-041 SAO短音效；低营收登记等缺口风险放行，不伪造登记。

### effort

2–4人日/首端估计

### paths

tools/spikes/sao_small/；tests/music/offline_loop/

### kind

V

### status

unvalidated

### rowOrder

17

### entryFile

tools/spikes/sao_small/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v017.py

### acceptanceCommand

python tools/spikes/sao_small/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-017.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-017@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-018 · YuE2乐谱规划/歌词/分轨Profile

### id

V-018

### title

YuE2乐谱规划/歌词/分轨Profile

### phase

D

### spec

- 8d
- 6b
- 1b
- 1c

### hardDeps

- V-001

### gates



### scope

含ABC/和弦编辑/人声伴奏能力探针；翻唱按实际API验，不造通用接口。

### steps

固定Linux/Python3.12/BF16组合→3份乐谱计划复用→生成/分轨→取消。

### deliverable

YuE2Profile、code/weight许可事实和能力矩阵。

### acceptance

3份plan可roundtrip无字段丢失；3段生成至少2段审听≥3.5/5；分轨SR/时码对齐；缺许可默认警告而非商业硬阻。

### profile

MUSIC-HEAVY：官方24GB BF16 GPU主线、我方64GB主存候选；未借到留未验证。

### decision

资源/质量不达标仅YuE2待适配；I-041不以它阻ACE；不会在本轮购授权或下载。

### effort

3–5人日估计

### paths

tools/spikes/yue2/；tests/music/score_stems/

### kind

V

### status

unvalidated

### rowOrder

18

### entryFile

tools/spikes/yue2/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v018.py

### acceptanceCommand

python tools/spikes/yue2/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-018.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-018@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-019 · 视频Provider真实模式与质量报价验证

### id

V-019

### title

视频Provider真实模式与质量报价验证

### phase

D

### spec

- 8
- 8i
- 8k
- 8m
- 8v
- 1c

### hardDeps

- V-001

### gates



### scope

逐Profile验证T2V/I2V/first-last/真续写/v2v；不以尾帧I2V冒充原生续写。

### steps

先官方请求golden→用户批准后最多6个付费/自有GPU样本→身份/运动/音接缝QA→对账。

### deliverable

VideoModeProfile、quote/SLA观察与unsupported清单。

### acceptance

请求能力字段100%对应官方版本；不支持模式提交数=0；6样本≥4个审片≥3.5/5为初始质量目标；unknown提交重POST=0。

### profile

VIDEO：自有GPU或明确批准的API；未审批费用/上传时只做协议mock，真实模式仍unvalidated。

### decision

不达→保显式模式阻断/替代提案；I-040逐模式准入，不改全产品定位。

### effort

3–5人日/首Provider估计，供应商等待另计

### paths

tools/spikes/video_provider/；tests/generation/mode_contract/

### kind

V

### status

unvalidated

### rowOrder

19

### entryFile

tools/spikes/video_provider/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v019.py

### acceptanceCommand

python tools/spikes/video_provider/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-019.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-019@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-020 · 影视QA与最小修复评测基线

### id

V-020

### title

影视QA与最小修复评测基线

### phase

B

### spec

- 8b
- 10f
- 10g
- 12e

### hardDeps



### gates



### scope

含叙事/人物/商品/运动/情绪/字幕视听标签；不靠一个LLM judge定真伪。

### steps

20个好/坏片段→人工标注→规则/模型分开评分→定位最小依赖子图。

### deliverable

QA阈值ADR、held-out标签集和修复oracle。

### acceptance

已知违规检测precision/recall初始目标≥0.8；unknown不自动判好；锁片段覆盖=0；正确镜头重生数=0；人工标注与模型评分分列。

### profile

EVAL：自拟/获权公开fixture；单人可隔日复标但不声称多人一致性；模型费用另审批。

### decision

不达→更多人工审片/调阈值，不降低事实与安全硬规则；I-035/I-057消费。

### effort

2–4人日/首基线估计

### paths

tools/eval/qa_baseline/；tests/quality/repair_graph/

### kind

V

### status

unvalidated

### rowOrder

20

### entryFile

tools/eval/qa_baseline/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v020.py

### acceptanceCommand

python tools/eval/qa_baseline/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-020.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-020@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-021 · 可选Serverless持久任务与成本spike

### id

V-021

### title

可选Serverless持久任务与成本spike

### phase

E

### spec

- 10h
- 10d
- 12
- 12c

### hardDeps



### gates



### scope

含业务API/DB/outbox/队列/对象存储边界；不选供应商/部署或开通。

### steps

本地模拟API/worker→100重复/乱序回调→提交unknown与恢复→成本公式。

### deliverable

BackendADR、幂等协议、费用模型和可选部署配方。

### acceptance

同idempotency key最多1次外部提交；100重复回调1次入账；lease过期仅1 writer；冷启/失败/存储/出口/审核成本项无遗漏。

### profile

BACKEND：本地容器/SQLite或Postgres模拟；真实云资源与供应商账号另审批。

### decision

失败修协议再选型；无供应商只保planned；I-051/I-052不阻本地App。

### effort

3–5人日估计

### paths

tools/spikes/serverless/；tests/backend/durable_callbacks/

### kind

V

### status

unvalidated

### rowOrder

21

### entryFile

tools/spikes/serverless/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v021.py

### acceptanceCommand

python tools/spikes/serverless/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-021.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-021@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-022 · 地区商店/支付/隐私发行验证

### id

V-022

### title

地区商店/支付/隐私发行验证

### phase

E

### spec

- 1a
- 1b
- 1c
- 12b
- 12c
- 12d
- 13

### hardDeps



### gates



### scope

含海外优先/国内独立配置、IAP/权益sandbox；不把项目策略当平台授权。

### steps

选目标store/地区→列事实与适用义务→沙盒receipt重放/退款→隐私权限走查。

### deliverable

ReleaseProfile、权益真值/审核资料清单与待定项。

### acceptance

重复receipt发放=1次；撤销后不新发额度；隐私声明与网络追踪一致；未获得账号/沙盒的测试留unvalidated，不伪填通过。

### profile

RELEASE：用户已有开发者账号/测试设备；注册/付费/提审另批准；许可缺口仅warning。

### decision

真实平台拒绝/鉴权不绕过；I-053/I-058按地区发布，国内服务与备案待定可单独延期。

### effort

2–4人日/首地区估计，审核时间不估

### paths

tools/release/profile_audit/；tests/billing/receipt_cases/

### kind

V

### status

unvalidated

### rowOrder

22

### entryFile

tools/release/profile_audit/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v022.py

### acceptanceCommand

python tools/release/profile_audit/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-022.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-022@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-023 · 模型/媒体资源共池与OS中断资格

### id

V-023

### title

模型/媒体资源共池与OS中断资格

### phase

C

### spec

- 6c
- 6d
- 8u
- 10c

### hardDeps

- V-002

### gates

- V-008=llm-pair
- V-009=asr-pair
- V-011=mask-pair

### scope

含选定重模型单租约与媒体争用；不把所有模型已过作前置。

### steps

选择LLM/ASR/mask中一个已验Profile→与预览并用→压力/后台→checkpoint复核。

### deliverable

ResourceProfile、增量分配ledger与不可恢复状态列表。

### acceptance

20分钟无OOM/死锁；shared只计一次；压力先暂停重模型；10次中断不丢durable chunk；device/ABI变更不恢复旧指针。

### profile

RESOURCE：llm-pair/asr-pair/mask-pair分别验对应已验模型；只证明所选组合，温度/OS/driver记录齐全。

### decision

不达→降低并发/尺寸或仅桌面开放；I-042消费，基础编辑仍可用。

### effort

3–5人日/设备组合估计

### paths

tools/spikes/resource_pool/；tests/runtime/os_interrupt/

### kind

V

### status

unvalidated

### rowOrder

23

### entryFile

tools/spikes/resource_pool/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v023.py

### acceptanceCommand

python tools/spikes/resource_pool/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-023.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-023@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-024 · limiter/响度与DSP确定性ADR

### id

V-024

### title

limiter/响度与DSP确定性ADR

### phase

E

### spec

- 4
- 7
- 8r

### hardDeps

- V-004

### gates



### scope

含true-peak/latency/overlap与许可事实；不把未定limiter塞默认导出。

### steps

选CPU DSP候选→脉冲/正弦/过载→lookahead/flush→与参考值比较。

### deliverable

AudioDSPADR、延迟合同和允许的preset。

### acceptance

目标true-peak≤设定ceiling+0.1dB；延迟补偿后相位/长度误差≤1sample；无NaN；同fixture输出误差在冻结容差内。

### profile

DSP：现有桌面/手机CPU，48k stereo，自拟信号；无付费API。

### decision

失败保基础gain/明确clip告警，高级limiter不启；I-060消费。

### effort

2–4人日估计

### paths

tools/spikes/limiter/；tests/audio/true_peak/

### kind

V

### status

unvalidated

### rowOrder

24

### entryFile

tools/spikes/limiter/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v024.py

### acceptanceCommand

python tools/spikes/limiter/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-024.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-024@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-025 · 多模态摄取/OCR/VL文本投影验证

### id

V-025

### title

多模态摄取/OCR/VL文本投影验证

### phase

B

### spec

- 8a
- 10a
- 12b

### hardDeps

- V-001

### gates

- V-002=video-decode
- V-009=video-asr

### scope

含文本/分页文件/OCR与视觉推断/视频抽帧ASR；不声称抽帧覆盖完整运动。

### steps

10份编码/分页文档+20图+5短视频→证据坐标映射→复用缓存→矛盾与删除。

### deliverable

AnalysisProfile、格式支持/限制及观察推断标注fixture。

### acceptance

已知文本事实提取准确率目标≥95%；每条事实证据页/框/PTS引用有效=100%；同hash同参数付费解析≤1；删除后命中=0。

### profile

ANALYSIS：本地OCR/ASR与可选已批准VL；云素材与费用未批只测本地/协议，不假称VL质量。

### decision

不达限制格式/分析层级或按需深读；I-028消费，纯文本会话不等这些模型。

### effort

3–5人日/首链估计

### paths

tools/spikes/multimodal/；tests/context/evidence_projection/

### kind

V

### status

unvalidated

### rowOrder

25

### entryFile

tools/spikes/multimodal/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v025.py

### acceptanceCommand

python tools/spikes/multimodal/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-025.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-025@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## V-026 · 可选glTF预览与不可信资源边界

### id

V-026

### title

可选glTF预览与不可信资源边界

### phase

E

### spec

- 4a
- 12

### hardDeps

- V-003

### gates



### scope

只验证受限glTF预览；不含NeRF/3DGS训练编辑。

### steps

审两候选runtime→3份≤10MiB公开模型→材质/相机→恶意外链/缓冲区。

### deliverable

Preview3DADR、library锁候选和feature范围。

### acceptance

3份fixture预览/归档重开一致；外部URL自动请求=0；100个损坏输入不越界/崩溃；未支持扩展显式拒绝。

### profile

3D：已有桌面GPU；模型许可事实照记；不因未知许可硬阻，但不可信输入仍拦。

### decision

失败保持3D预览实验；I-061只在明确纳入版本时执行。

### effort

2–4人日估计

### paths

tools/spikes/gltf/；tests/graphics/untrusted_3d/

### kind

V

### status

unvalidated

### rowOrder

26

### entryFile

tools/spikes/gltf/run_probe.py

### acceptanceAdapter

tools/acceptance/cases/v026.py

### acceptanceCommand

python tools/spikes/gltf/run_probe.py --profile <FROZEN_PROFILE> --report artifacts/acceptance/V-026.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

V-026@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-001 · 共享workspace与双宿主AppProfile骨架

### id

I-001

### title

共享workspace与双宿主AppProfile骨架

### phase

A

### spec

- 0
- 1
- 6
- 12

### hardDeps



### gates



### scope

含package依赖/本地端口/namespace；不含模型或真实商业后端。

### steps

建拟议目录→固定依赖接口→image/studio两demo注入不同Profile。

### deliverable

可构建骨架、ADR、统一验收runner及CI配方。

### acceptance

flutter analyze/dart test零错误；两App同asset字节但session不可互读；runner未知任务非零退出。

### profile

DEV：现有开发机；未来构建用V-001工具链，缺端工具只留本端未验。

### decision

通过后纯逻辑并行；构建未验不标全平台支持。

### effort

2–4人日估计

### paths

apps/{studio_demo,image_demo}/；packages/studio_sdk/；tools/acceptance/run_task.py

### kind

I

### status

planned

### rowOrder

27

### entryFile

packages/studio_sdk/lib/studio_sdk.dart

### acceptanceAdapter

tools/acceptance/cases/i001.py

### acceptanceCommand

python tools/acceptance/run_task.py I-001 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-001.json

### singlePersonPriority

1 首组

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-001@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-002 · 完整Schema与有理时间领域核

### id

I-002

### title

完整Schema与有理时间领域核

### phase

A

### spec

- 2
- 5a
- 8g
- 8n
- 8u
- 10i

### hardDeps

- I-001

### gates



### scope

含全部现行Schema/语义/版本合同；不改闭合根塞新字段。

### steps

移入schema数据→BigInt/帧sample换算→FK/区间/DAG语义→迁移拒绝规则。

### deliverable

studio_document序列化/validator与golden fixture。

### acceptance

1万次有理运算/往返无漂移；非法FK/交叠/overflow全拒；现有合成项目通过；结构与业务错误分开。

### profile

DEV-PURE：无需模型/GPU/服务。

### decision

失败保持事务不写；给精确错误码再修，不吞未知字段。

### effort

3–5人日估计

### paths

packages/studio_document/lib/{time,validator}.dart；test/schema_time/

### kind

I

### status

planned

### rowOrder

28

### entryFile

packages/studio_document/lib/time.dart

### acceptanceAdapter

tools/acceptance/cases/i002.py

### acceptanceCommand

python tools/acceptance/run_task.py I-002 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-002.json

### singlePersonPriority

1 首组

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-002@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-003 · Project事务、revision与数据库真值

### id

I-003

### title

Project事务、revision与数据库真值

### phase

A

### spec

- 2
- 5a
- 9
- 10i

### hardDeps

- I-002

### gates



### scope

含SQLite/CAS/revision/单写者fence；不做多人实时协作。

### steps

DDL迁移→command事务→journal/outbox绑定→双App隔离。

### deliverable

DocumentRepository/CommitCoordinator与receipt合同。

### acceptance

100次并发同baseRevision仅1次成功；撤销产生新revision；事务故障无半写；namespace越界读写=0。

### profile

DEV-PURE：内存DB＋临时文件DB。

### decision

冲突返回REVISION_CONFLICT，不后台覆盖手工变更。

### effort

3–5人日估计

### paths

packages/studio_store/lib/commit_coordinator.dart；test/store/transactions/

### kind

I

### status

planned

### rowOrder

29

### entryFile

packages/studio_store/lib/commit_coordinator.dart

### acceptanceAdapter

tools/acceptance/cases/i003.py

### acceptanceCommand

python tools/acceptance/run_task.py I-003 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-003.json

### singlePersonPriority

1 首组

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-003@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-004 · CAS素材导入/外链/丢失重链接

### id

I-004

### title

CAS素材导入/外链/丢失重链接

### phase

A

### spec

- 5
- 5a
- 5d
- 8a

### hardDeps

- I-003

### gates



### scope

含hash/原件/代理引用与完成占位；不自动上传或删原件。

### steps

FileToken导入→流式hash→metadata占位→重链接/重复素材复用。

### deliverable

BlobStore/AssetRepository/RelinkProposal。

### acceptance

同hash多引用仅1blob；部分导入不可导出；错hash重链接拒绝；撤销引用不删仍可达原件。

### profile

DEV：合成文件/临时目录；无用户照片。

### decision

无权限/丢失返回可恢复状态；不偷偷下载外链。

### effort

2–4人日估计

### paths

packages/studio_store/lib/blob_store.dart；test/assets/lifecycle/

### kind

I

### status

planned

### rowOrder

30

### entryFile

packages/studio_store/lib/blob_store.dart

### acceptanceAdapter

tools/acceptance/cases/i004.py

### acceptanceCommand

python tools/acceptance/run_task.py I-004 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-004.json

### singlePersonPriority

1 首组

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-004@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-005 · NLE基础选择/移动/拆分/插入覆盖

### id

I-005

### title

NLE基础选择/移动/拆分/插入覆盖

### phase

A

### spec

- 2
- 3

### hardDeps

- I-003

### gates



### scope

含Gap/多选/吸附/复制粘贴/编组；不含高级trim。

### steps

纯函数计划→区间碰撞→link传播→命令/逆操作。

### deliverable

白名单EditCommand与基础操作golden。

### acceptance

第3节每操作正反例通过；1千随机序列undo后文档hash相等；锁定成员与负区间整组拒。

### profile

DEV-PURE：不依赖视频解码。

### decision

失败revision不变、错误可定位；UI拖动只ghost。

### effort

3–5人日估计

### paths

packages/studio_document/lib/edit_algebra.dart；test/nle/basic/

### kind

I

### status

planned

### rowOrder

31

### entryFile

packages/studio_document/lib/edit_algebra.dart

### acceptanceAdapter

tools/acceptance/cases/i005.py

### acceptanceCommand

python tools/acceptance/run_task.py I-005 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-005.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-005@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-006 · trim/ripple/roll/slip/slide联动编辑

### id

I-006

### title

trim/ripple/roll/slip/slide联动编辑

### phase

A

### spec

- 3
- 5a

### hardDeps

- I-005

### gates



### scope

含轨锁/syncLock/link/unlink/多轨边界；不静默破同步。

### steps

实现区间方程→碰撞预检→一次事务→inverse patch。

### deliverable

TrimPlanner与每类最小反例。

### acceptance

全部trim模式逐条含handles/跨链接/锁轨断言；1千随机合法输入长度/源范围守恒；失败不半写。

### profile

DEV-PURE：有理时间fixture。

### decision

源不足/锁冲突整命令拒；不可擅自删邻clip。

### effort

3–5人日估计

### paths

packages/studio_document/lib/trim_planner.dart；test/nle/trim_modes/

### kind

I

### status

planned

### rowOrder

32

### entryFile

packages/studio_document/lib/trim_planner.dart

### acceptanceAdapter

tools/acceptance/cases/i006.py

### acceptanceCommand

python tools/acceptance/run_task.py I-006 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-006.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-006@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-007 · 变速重映射与Compound/Nest

### id

I-007

### title

变速重映射与Compound/Nest

### phase

A

### spec

- 2
- 3
- 4

### hardDeps

- I-006

### gates



### scope

含分段速度/逆映射/嵌套DAG；不默认光流补帧。

### steps

timeMap采样→拆分/复制重基→nest展开→源PTS映射。

### deliverable

RetimeMap/NestResolver与sourceAt测试。

### acceptance

30000/1001与48k组合无累计漂移；反向/重复PTS按合同；嵌套环全拒；字幕anchor不误用帧索引。

### profile

DEV-PURE，真实播放资格另由V-003。

### decision

不支持插帧模式明确降级提案，不能改片长偷过。

### effort

3–5人日估计

### paths

packages/studio_document/lib/{retime,nest}.dart；test/nle/retime/

### kind

I

### status

planned

### rowOrder

33

### entryFile

packages/studio_document/lib/retime.dart

### acceptanceAdapter

tools/acceptance/cases/i007.py

### acceptanceCommand

python tools/acceptance/run_task.py I-007 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-007.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-007@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-008 · EffectRegistry/关键帧/确定性转场

### id

I-008

### title

EffectRegistry/关键帧/确定性转场

### phase

A

### spec

- 4
- 4a
- 7a
- 8f

### hardDeps

- I-005

### gates

- V-003=render

### scope

含基础变换/透明度/叠化/注册luma；不默认未注册插件或高级调色。

### steps

注册effect schema→插值→handles验证→CPU节点/图编译描述。

### deliverable

EffectRegistry/TransitionCompiler与snapshot。

### acceptance

缺handles拒；未知技术UNSUPPORTED_EDIT_TECHNIQUE；关键帧边界连续；一次提案原子undo恢复hash。

### profile

DEV：CPU golden；GPU真实一致性由V-003。

### decision

注册外效果只读保留或显式不支持，不静默丢弃。

### effort

3–5人日估计

### paths

packages/studio_document/lib/effect_registry.dart；native/studio_media/effects/；test/effects/

### kind

I

### status

planned

### rowOrder

34

### entryFile

packages/studio_document/lib/effect_registry.dart

### acceptanceAdapter

tools/acceptance/cases/i008.py

### acceptanceCommand

python tools/acceptance/run_task.py I-008 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-008.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-008@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-009 · AudioBus/音量关键帧与基础混音语义

### id

I-009

### title

AudioBus/音量关键帧与基础混音语义

### phase

A

### spec

- 4
- 8d
- 8r

### hardDeps

- I-003

### gates



### scope

含mute/solo/link/gain与路由；不偷启limiter。

### steps

总线DAG→自动化sample映射→duck提案保护锁→输出DSP recipe。

### deliverable

AudioBusGraph与gain automation合同。

### acceptance

总线路由环拒绝；相同cue变速后音频锚点正确；手调音量/锁轨修改=0；silent track不混入。

### profile

DEV-PURE＋自拟48k信号；输出设备另任务。

### decision

clip告警而非静默限幅；高级DSP留I-060。

### effort

2–4人日估计

### paths

packages/studio_document/lib/audio_bus.dart；test/audio/automation/

### kind

I

### status

planned

### rowOrder

35

### entryFile

packages/studio_document/lib/audio_bus.dart

### acceptanceAdapter

tools/acceptance/cases/i009.py

### acceptanceCommand

python tools/acceptance/run_task.py I-009 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-009.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-009@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-010 · 字幕cue编辑/格式与手改锁

### id

I-010

### title

字幕cue编辑/格式与手改锁

### phase

A

### spec

- 3
- 8r
- 12d

### hardDeps

- I-005

### gates



### scope

含SRT/VTT/ASS受支持子集、样式/字体fallback；不宣称任意ASS效果往返无损。

### steps

cue模型→split/trim/timeMap→文本编辑锁→格式导入导出。

### deliverable

CaptionStore/FormatAdapter与goldens。

### acceptance

emoji/RTL/换行/非整帧时码往返；不支持样式告警；重新ASR不覆盖手改cue；重叠cue策略确定。

### profile

DEV：获许可测试字体，无云。

### decision

字体缺失列替代与版式变化，不偷偷当原字体。

### effort

2–4人日估计

### paths

packages/studio_document/lib/caption.dart；test/captions/formats/

### kind

I

### status

planned

### rowOrder

36

### entryFile

packages/studio_document/lib/caption.dart

### acceptanceAdapter

tools/acceptance/cases/i010.py

### acceptanceCommand

python tools/acceptance/run_task.py I-010 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-010.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-010@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-011 · journal/snapshot与工程包原子写入

### id

I-011

### title

journal/snapshot与工程包原子写入

### phase

A

### spec

- 5
- 5a
- 5b
- 5c
- 5e

### hardDeps

- I-003
- I-004

### gates

- V-005=durable-storage

### scope

含manifest校验/单writer/崩溃恢复；不把session DB混进项目。

### steps

写blob→journal→snapshot→commit marker→恢复扫描。

### deliverable

CheckpointStore/ProjectPackageWriter/RecoveryService。

### acceptance

各崩溃点注入后只开最后好snapshot+tail；durableRevision不虚报；损坏唯一好副本不覆盖；Schema完整往返。

### profile

DEV：临时目录；真实provider资格消费V-005。

### decision

磁盘满/拔盘进可恢复错误，不显示保存完成。

### effort

3–5人日估计

### paths

packages/studio_store/lib/{package_writer,recovery}.dart；test/storage/crash_points/

### kind

I

### status

planned

### rowOrder

37

### entryFile

packages/studio_store/lib/package_writer.dart

### acceptanceAdapter

tools/acceptance/cases/i011.py

### acceptanceCommand

python tools/acceptance/run_task.py I-011 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-011.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-011@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-012 · 显式保存/自动保存/另存为UI状态

### id

I-012

### title

显式保存/自动保存/另存为UI状态

### phase

A

### spec

- 5b
- 5c
- 5e

### hardDeps

- I-011

### gates

- V-005=durable-storage

### scope

含debounce/最大间隔/退出触发与保存中续编；不等同同步或导出。

### steps

SaveCoordinator→AutosaveScheduler→状态流→取消/重试。

### deliverable

DocumentLifecycle与保存状态UI。

### acceptance

虚拟时钟验证全部触发；并发save合并；head继续编辑不伪改userSavedRevision；保存完成只在durable receipt之后。

### profile

DEV：fake clock；P0真实fsync需V-005。

### decision

不可写时保dirty/错误提示，退出询问不擅自丢内容。

### effort

2–4人日估计

### paths

packages/studio_store/lib/save_coordinator.dart；packages/studio_editor_ui/save/；test/save/

### kind

I

### status

planned

### rowOrder

38

### entryFile

packages/studio_store/lib/save_coordinator.dart

### acceptanceAdapter

tools/acceptance/cases/i012.py

### acceptanceCommand

python tools/acceptance/run_task.py I-012 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-012.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-012@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-013 · 备份/归档闭包与可再分发清单

### id

I-013

### title

备份/归档闭包与可再分发清单

### phase

A

### spec

- 5d
- 5e
- 8g
- 8u

### hardDeps

- I-011
- I-004

### gates

- V-005=archive-storage

### scope

含逻辑archive和自包含包/代理/外链模式；不删原件或默认取消付费job。

### steps

固定revision→引用闭包/空间预检→流式hash打包→增量备份可达GC。

### deliverable

ArchiveService/BackupPolicy与缺失/限制清单。

### acceptance

运行job归档固定rev并报告pending；凭据/已删正文不入包；不可打包资源显式manifest；取消无半包发布；保留策略不删可达blob。

### profile

DEV：合成角色/音乐/技能引用与临时文件。

### decision

缺资源/许可事实列清单；许可不足按1C警告，实际分享/删除另确认。

### effort

3–5人日估计

### paths

packages/studio_store/lib/archive_service.dart；test/archive/closure_gc/

### kind

I

### status

planned

### rowOrder

39

### entryFile

packages/studio_store/lib/archive_service.dart

### acceptanceAdapter

tools/acceptance/cases/i013.py

### acceptanceCommand

python tools/acceptance/run_task.py I-013 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-013.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-013@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-014 · 安全恢复/fork/版本迁移与跨App导入

### id

I-014

### title

安全恢复/fork/版本迁移与跨App导入

### phase

A

### spec

- 5a
- 5d
- 5e
- 8g

### hardDeps

- I-013

### gates



### scope

含ID重映射/未来major只读/旧版本恢复新rev；不覆盖既有文件。

### steps

校验hash/zip边界→版本检查→staging迁移→引用重绑。

### deliverable

RestoreService/MigrationRegistry与恶意归档fixture。

### acceptance

zip slip/炸弹/符号链接/自动外链均拒；恢复不倒退事件；fork新projectId；迁移中断保好副本；不支持feature只读保留。

### profile

DEV-PURE＋临时文件，无用户归档。

### decision

冲突需用户选另名/确认覆盖；不能因缺插件静默删效果。

### effort

3–5人日估计

### paths

packages/studio_store/lib/restore_service.dart；test/archive/security_migration/

### kind

I

### status

planned

### rowOrder

40

### entryFile

packages/studio_store/lib/restore_service.dart

### acceptanceAdapter

tools/acceptance/cases/i014.py

### acceptanceCommand

python tools/acceptance/run_task.py I-014 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-014.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-014@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-015 · FFmpeg共享C ABI与能力探测层

### id

I-015

### title

FFmpeg共享C ABI与能力探测层

### phase

A

### spec

- 6
- 7
- 7a
- 7b

### hardDeps

- I-001
- I-002

### gates

- V-002=codec

### scope

含libav*封装/AVIO授权/内存错误/取消；不依赖FFmpegKit旧binary。

### steps

锁构建→C ABI句柄→probe/demux/packet→Dart FFI测试。

### deliverable

MediaPort ABI、build manifest与native单测。

### acceptance

异常不穿C ABI；borrow/retain/release配对；100次开关0活句柄；越权路径/网络读取=0。

### profile

BUILD/MEDIA：未来P0工具链；不接用户工程。

### decision

能力失败返回typed error；商业许可缺口登记warning不篡改事实。

### effort

3–5人日估计

### paths

native/studio_media/c_api.*；packages/studio_media_ffi/；test/ffi/

### kind

I

### status

planned

### rowOrder

41

### entryFile

native/studio_media/c_api.cpp

### acceptanceAdapter

tools/acceptance/cases/i015.py

### acceptanceCommand

python tools/acceptance/run_task.py I-015 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-015.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-015@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-016 · Apple VideoToolbox/Metal/CoreAudio端口

### id

I-016

### title

Apple VideoToolbox/Metal/CoreAudio端口

### phase

A

### spec

- 6
- 6a
- 7a

### hardDeps

- I-015

### gates

- V-002=apple-codec
- V-003=apple-render
- V-004=apple-clock

### scope

含iOS/iPadOS/macOS共享Apple适配；不保证三端散热相同或全零拷贝。

### steps

CVPixelBuffer池→Metal纹理fence→encoder→AudioSink/生命周期。

### deliverable

AppleMediaPort与每OS资格记录。

### acceptance

目标decode/compose/encode通过；CV/CF只释放一次；取消100轮无pool泄漏；后台到期checkpoint而非假完成。

### profile

APPLE：现有或借测Mac/手机；无Mac时此端留未验，不阻Android/Windows。

### decision

共享内核不复制AVFoundation另一套timeline；不匹配格式显式copy。

### effort

3–5人日/首端，iPad/mac差异另1–3估计

### paths

native/platform/apple/；test/platform/apple/

### kind

I

### status

planned

### rowOrder

42

### entryFile

native/platform/apple/apple_media_port.mm

### acceptanceAdapter

tools/acceptance/cases/i016.py

### acceptanceCommand

python tools/acceptance/run_task.py I-016 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-016.json

### singlePersonPriority

P0只选匹配现有设备的一个；其他端独立排期

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-016@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-017 · Android MediaCodec/Surface/AAudio端口

### id

I-017

### title

Android MediaCodec/Surface/AAudio端口

### phase

A

### spec

- 6
- 6a
- 7a

### hardDeps

- I-015

### gates

- V-002=android-codec
- V-003=android-render
- V-004=android-clock

### scope

含Surface encoder/CSD归一/NDK生命周期；不把AHardwareBuffer冒充任意FFmpeg帧。

### steps

decoder Surface→稳定FBO→encoder EGLSurface→packet→AAudio。

### deliverable

AndroidMediaPort与SKU/driver能力表。

### acceptance

1080p30样本10次可重开；Surface/JNI引用无泄漏；设备丢失可恢复；编码失败无空成片发布。

### profile

ANDROID：现有/借测API31+ ARM64；GPU厂商逐个资格。

### decision

driver不兼容用已验copy路径或能力关闭，不静默云。

### effort

3–5人日/首SKU估计

### paths

native/platform/android/；test/platform/android/

### kind

I

### status

planned

### rowOrder

43

### entryFile

native/platform/android/android_media_port.cpp

### acceptanceAdapter

tools/acceptance/cases/i017.py

### acceptanceCommand

python tools/acceptance/run_task.py I-017 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-017.json

### singlePersonPriority

P0只选匹配现有设备的一个；其他端独立排期

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-017@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-018 · Windows D3D11/MF/WASAPI端口

### id

I-018

### title

Windows D3D11/MF/WASAPI端口

### phase

A

### spec

- 6
- 6a
- 7a

### hardDeps

- I-015

### gates

- V-002=windows-codec
- V-003=windows-render
- V-004=windows-clock

### scope

含MTA worker/DXGI纹理/device manager；不承诺所有Windows GPU硬编。

### steps

MFT配置→同device纹理池→packet/mux→WASAPI时钟。

### deliverable

WindowsMediaPort与driver资格表。

### acceptance

NV12路径/CPU copy差异显式；COM线程与Release配对；设备重置后不复用失效纹理；20次seek±1帧。

### profile

WINDOWS：已有Windows11 x64，集显与独显按可借设备。

### decision

硬件失败只提已验软件/替代preset；不绕过系统MFT拒绝。

### effort

3–5人日/首GPU估计

### paths

native/platform/win/；test/platform/windows/

### kind

I

### status

planned

### rowOrder

44

### entryFile

native/platform/win/windows_media_port.cpp

### acceptanceAdapter

tools/acceptance/cases/i018.py

### acceptanceCommand

python tools/acceptance/run_task.py I-018 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-018.json

### singlePersonPriority

P0只选匹配现有设备的一个；其他端独立排期

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-018@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-019 · Linux VAAPI/GL/PipeWire端口

### id

I-019

### title

Linux VAAPI/GL/PipeWire端口

### phase

E

### spec

- 6
- 6a
- 7a

### hardDeps

- I-015

### gates

- V-002=linux-codec
- V-003=linux-render
- V-004=linux-clock

### scope

含Ubuntu24.04原生目标；不视所有DMABUF modifier通用。

### steps

VAAPI帧→DRM/EGL同步→编码→PipeWire及显式ALSA兼容。

### deliverable

LinuxMediaPort与Wayland/X11资格范围。

### acceptance

目标样本导出/音画时钟通过；modifier不匹配显式copy；100轮取消无fd泄漏。

### profile

LINUX：现有/借测GPU；不强制购买NVIDIA。

### decision

失败本端实验性；不会阻Apple/Android/Windows首个闭环。

### effort

3–5人日/首GPU估计

### paths

native/platform/linux/；test/platform/linux/

### kind

I

### status

planned

### rowOrder

45

### entryFile

native/platform/linux/linux_media_port.cpp

### acceptanceAdapter

tools/acceptance/cases/i019.py

### acceptanceCommand

python tools/acceptance/run_task.py I-019 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-019.json

### singlePersonPriority

P0只选匹配现有设备的一个；其他端独立排期

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-019@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-020 · 独立WebMediaPort与OPFS工程适配

### id

I-020

### title

独立WebMediaPort与OPFS工程适配

### phase

E

### spec

- 6
- 7
- 5c

### hardDeps

- I-002
- I-003
- I-024

### gates

- V-007=web-media

### scope

含Worker/WebCodecs/JS demux mux/存储配额；不加载native硬件AVFrame。

### steps

采用已选库→实现同语义recipe→VideoFrame close→配额/后台恢复。

### deliverable

Web端受限能力包与不支持UI。

### acceptance

60秒roundtrip时长≤1帧误差；未支持codec不提交；OPFS驱逐可恢复提示；同工程与原生金样命令语义一致。

### profile

WEB：V-007已验浏览器，本地安全origin；无付费服务。

### decision

不满足时保会话/图像/只读，不承诺移动Web全功能。

### effort

3–5人日/基础profile估计

### paths

packages/studio_web_media/；test/web/roundtrip/

### kind

I

### status

planned

### rowOrder

46

### entryFile

packages/studio_web_media/lib/web_media_port.dart

### acceptanceAdapter

tools/acceptance/cases/i020.py

### acceptanceCommand

python tools/acceptance/run_task.py I-020 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-020.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-020@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-021 · 解码/精确seek/代理与帧缓存

### id

I-021

### title

解码/精确seek/代理与帧缓存

### phase

A

### spec

- 6
- 7
- 7a

### hardDeps

- I-004
- I-015

### gates

- V-004=seek-load

### scope

含PTS索引/VFR/代理时间映射/LRU；不做每次seek全片解码。

### steps

demux seek→前滚解码→sourceAt选帧→代理匹配→背压缓存。

### deliverable

DecoderSession/SeekPlanner/ProxyResolver。

### acceptance

20点seek±1帧；VFR/非零PTS不误映射；缓存<=预算；取消epoch前帧不回流预览。

### profile

MEDIA：P0端口按16B匹配，不要求所有端完成。

### decision

代理缺失用原件/明确重建；不得修改源PTS冒充归一。

### effort

3–5人日估计

### paths

native/studio_media/{decode,seek,cache}/；test/media/seek_proxy/

### kind

I

### status

planned

### rowOrder

47

### entryFile

native/studio_media/seek/seek_planner.cpp

### acceptanceAdapter

tools/acceptance/cases/i021.py

### acceptanceCommand

python tools/acceptance/run_task.py I-021 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-021.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-021@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-022 · 统一RenderGraph与纹理所有权

### id

I-022

### title

统一RenderGraph与纹理所有权

### phase

A

### spec

- 4
- 7a

### hardDeps

- I-008
- I-015
- I-021

### gates

- V-003=render

### scope

含CPU参考/本端GPU节点/preview-export共图；不截图预览导出。

### steps

RenderRecipe拓扑→资源池/fence→合成节点→取消/设备失联。

### deliverable

GraphCompiler/FrameLease与goldens。

### acceptance

同revision预览/编码前取样在V-003容差内；free仅在GPU/encoder消费后；100次取消无frame泄漏。

### profile

MEDIA：一个已验原生端，其他端独立资格。

### decision

未注册节点明确unsupported；不另建FFmpeg命令串时间线。

### effort

3–5人日/基础节点估计

### paths

native/studio_media/render_graph/；test/render/ownership/

### kind

I

### status

planned

### rowOrder

48

### entryFile

native/studio_media/render_graph/graph_compiler.cpp

### acceptanceAdapter

tools/acceptance/cases/i022.py

### acceptanceCommand

python tools/acceptance/run_task.py I-022 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-022.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-022@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-023 · 音频混音执行与主时钟

### id

I-023

### title

音频混音执行与主时钟

### phase

A

### spec

- 4
- 7
- 7a

### hardDeps

- I-009
- I-015

### gates

- V-004=audio-clock

### scope

含48k float总线/resample delay flush/ring；不以提交sample数当已播放时钟。

### steps

DSP recipe→buffer mix→AudioSink clock→seek/drain同步。

### deliverable

AudioMixer/AudioClock与延迟补偿测试。

### acceptance

60秒音画偏差≤20ms；脉冲长度±1sample；mute/solo正确；ring有界、设备切换可暂停重绑。

### profile

MEDIA：P0 CoreAudio/AAudio/WASAPI/PipeWire之一。

### decision

underrun记录/降负载，不静默拉伸输出音频。

### effort

3–5人日估计

### paths

native/studio_media/audio_mixer/；test/audio/clock_sink/

### kind

I

### status

planned

### rowOrder

49

### entryFile

native/studio_media/audio_mixer/audio_clock.cpp

### acceptanceAdapter

tools/acceptance/cases/i023.py

### acceptanceCommand

python tools/acceptance/run_task.py I-023 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-023.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-023@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-024 · 共享导出计划/编码mux与原子发布

### id

I-024

### title

共享导出计划/编码mux与原子发布

### phase

A

### spec

- 7
- 7a
- 5c

### hardDeps

- I-021
- I-022
- I-023
- I-011

### gates

- V-002=export-codec
- V-003=export-render
- V-004=export-clock

### scope

含H264/AAC基础preset/drain/DTS/校验；不默认smart-render。

### steps

编译固定rev→选择已验本端encoder→mux trailer→验证→atomic发布。

### deliverable

ExportService与完整60秒成片golden。

### acceptance

时长误差≤1帧、音画≤20ms、无黑/丢帧异常；失败/取消无损坏成片伪成功；revision固定不被编辑中途改。

### profile

MEDIA/STORAGE：至少一个匹配平台端口+V-005存储资格。

### decision

无码器/磁盘满明确失败；改HDR/fps/上传须新审批。

### effort

3–5人日估计

### paths

packages/studio_export/；native/studio_media/export/；test/export/e2e/

### kind

I

### status

planned

### rowOrder

50

### entryFile

packages/studio_export/lib/export_service.dart

### acceptanceAdapter

tools/acceptance/cases/i024.py

### acceptanceCommand

python tools/acceptance/run_task.py I-024 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-024.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-024@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-025 · 时间线/Inspector完整基础竖切UI

### id

I-025

### title

时间线/Inspector完整基础竖切UI

### phase

A

### spec

- 3
- 9
- 11
- 12d

### hardDeps

- I-005
- I-006
- I-010
- I-012
- I-024

### gates



### scope

含触摸/键盘选择trim/undo/diff；不等全部模型再可用。

### steps

绑定命令状态→导入/编辑/保存→杀进程重开→本地导出。

### deliverable

P0可操作demo与录屏/自动化脚本。

### acceptance

60秒6clip工程：手改字幕/trim/撤销/保存重开后等值；恢复最后durable编辑；导出通过I-024；无隐藏上传。

### profile

UI-P0：未来现有或借测设备；不访问旧私有工程。

### decision

失败归属具体命令/存储/媒体任务，不把UI截图当完成。

### effort

3–5人日估计

### paths

packages/studio_editor_ui/{timeline,inspector}/；integration_test/basic_cut/

### kind

I

### status

planned

### rowOrder

51

### entryFile

packages/studio_editor_ui/lib/timeline/timeline_view.dart

### acceptanceAdapter

tools/acceptance/cases/i025.py

### acceptanceCommand

python tools/acceptance/run_task.py I-025 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-025.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-025@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-026 · 图片图层/可编辑模板/传统风格

### id

I-026

### title

图片图层/可编辑模板/传统风格

### phase

A

### spec

- 4a
- 4b
- 9

### hardDeps

- I-003
- I-004
- I-008

### gates

- V-003=image-render

### scope

含图层/蒙版/文字/transform/模板槽与可逆参考调色；不缩产品成贴纸。

### steps

图层文档→模板参数校验→非破坏效果→导出/恢复。

### deliverable

ImageDocument与模板编辑UI。

### acceptance

10个图层模板往返不扁平化；原件hash不变；锁层不受批量调色影响；缺字体/effect显式降级。

### profile

DEV＋本端GPU；高级HDR/3D另任务。

### decision

参考风格建议可拒绝，不能将推断颜色当原图事实。

### effort

3–5人日/基础子集估计

### paths

packages/studio_image_editor/；test/graphics/layer_templates/

### kind

I

### status

planned

### rowOrder

52

### entryFile

packages/studio_image_editor/lib/image_document.dart

### acceptanceAdapter

tools/acceptance/cases/i026.py

### acceptanceCommand

python tools/acceptance/run_task.py I-026 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-026.json

### singlePersonPriority

2 基础闭环

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-026@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-027 · 独立Session/Branch消息与项目映射

### id

I-027

### title

独立Session/Branch消息与项目映射

### phase

B

### spec

- 9
- 10
- 10b
- 12a

### hardDeps

- I-003

### gates



### scope

含新建/命名/归档/搜索/fork/resume/显式挑patch；不偷共享跨App会话。

### steps

Session DDL→消息成对→branch CAS→revision引用→删除恢复UI。

### deliverable

SessionStore/BranchService与聊天工作台。

### acceptance

同一项目两个会话作用域隔离；tool-call/result配对；fork/resume不重放HTTP副作用；删除正文不留可搜索副本。

### profile

DEV-PURE：本地SQLite合成对话。

### decision

冲突显式分支或选patch，不假通用语义merge。

### effort

3–5人日估计

### paths

packages/studio_harness/lib/session_store.dart；test/session/branches/

### kind

I

### status

planned

### rowOrder

53

### entryFile

packages/studio_harness/lib/session_store.dart

### acceptanceAdapter

tools/acceptance/cases/i027.py

### acceptanceCommand

python tools/acceptance/run_task.py I-027 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-027.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-027@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-028 · Attachment摄取/分析工件/证据投影

### id

I-028

### title

Attachment摄取/分析工件/证据投影

### phase

B

### spec

- 8a
- 8u
- 12b

### hardDeps

- I-004
- I-027

### gates

- V-025=multimodal-analysis

### scope

含文本文件分页/图片OCR/VL/视频抽帧ASR引用；不等同完整视觉运动理解。

### steps

ContentPart规范化→可用分析pipeline→artifact→统一文本投影/按需深读。

### deliverable

IngestService/AnalysisArtifact/ProjectionCompiler。

### acceptance

超限不静默截断；观察/推断分离；hash+模型参数缓存去重；页/框/PTS可追溯；同意缺失不上传。

### profile

ANALYSIS：先本地文本fixture，模型分支按V-025开放。

### decision

不支持格式/能力显示partial coverage；纯文本入口可先完成。

### effort

3–5人日估计

### paths

packages/studio_context/lib/{ingest,projection}.dart；test/context/attachments/

### kind

I

### status

planned

### rowOrder

54

### entryFile

packages/studio_context/lib/ingest.dart

### acceptanceAdapter

tools/acceptance/cases/i028.py

### acceptanceCommand

python tools/acceptance/run_task.py I-028 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-028.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-028@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-029 · 有效意图/遗忘/压缩水位线

### id

I-029

### title

有效意图/遗忘/压缩水位线

### phase

B

### spec

- 10a
- 12a
- 8a

### hardDeps

- I-027
- I-028

### gates



### scope

含supersede/retract/delete/undo/并发与RAG失效；不只用聊天摘要作真值。

### steps

事件reduce→意图/约束索引→snapshot+tail原子压缩→删除传播。

### deliverable

ContextCompiler/DeletionBarrier/CompactionStore。

### acceptance

千事件变更/删除后旧约束复活=0；watermark变更重建；provider已存正文只报告其删除限制；素材删改不因指代猜测执行。

### profile

DEV-PURE：合成文本/分析artifact。

### decision

冲突要澄清，不能暗删源文件或恢复已删正文。

### effort

3–5人日估计

### paths

packages/studio_context/lib/{reducer,compaction,deletion}.dart；test/context/forget/

### kind

I

### status

planned

### rowOrder

55

### entryFile

packages/studio_context/lib/compaction.dart

### acceptanceAdapter

tools/acceptance/cases/i029.py

### acceptanceCommand

python tools/acceptance/run_task.py I-029 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-029.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-029@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-030 · 模型Provider流式工具适配

### id

I-030

### title

模型Provider流式工具适配

### phase

B

### spec

- 10
- 10b
- 12a

### hardDeps

- I-027

### gates

- V-008=local-llm

### scope

含llama.cpp与一个云文本适配接口/非原生tool JSON；不绑SDK会话。

### steps

CanonicalContext→provider模板→chunk/tool组装→typed终态。

### deliverable

ModelProvider ABI、local adapter与fixture流。

### acceptance

截断/乱序/重复chunk不执行半工具；tool schema全校验；模型不支持tool时显式约束/拒绝；模型pin记实际值。

### profile

DEV：fake流先行；真实本地需V-008；云无账号不自动调用。

### decision

JSON修复有界；失败返回候选解释不伪造执行。

### effort

3–5人日估计

### paths

packages/studio_models/lib/；native/studio_llm/；test/models/stream_tools/

### kind

I

### status

planned

### rowOrder

56

### entryFile

packages/studio_models/lib/model_provider.dart

### acceptanceAdapter

tools/acceptance/cases/i030.py

### acceptanceCommand

python tools/acceptance/run_task.py I-030 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-030.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-030@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-031 · Harness主循环/受限工具/Hook顺序

### id

I-031

### title

Harness主循环/受限工具/Hook顺序

### phase

B

### spec

- 10b
- 10d
- 12b

### hardDeps

- I-030
- I-029
- I-003

### gates



### scope

含turn/run/step/job、steer/排队/取消、middleware failclosed；不保存私密推理链。

### steps

事件主循环→权限工具注册→hooks超时→tool成对终态→结果回流。

### deliverable

HarnessRuntime/ToolRuntime/HookChain与trace。

### acceptance

重复消息只执行1次；审批前工具副作用=0；hook不能提权；异常/timeout产生可恢复错误；晚到不覆盖手改。

### profile

DEV：合成Provider/Clock/Tool ports。

### decision

plan摘要与简短理由可见；未知hook故障failclosed，不绕过平台检查。

### effort

3–5人日估计

### paths

packages/studio_harness/lib/{runtime,tool_runtime,hooks}.dart；test/harness/turn_loop/

### kind

I

### status

planned

### rowOrder

57

### entryFile

packages/studio_harness/lib/runtime.dart

### acceptanceAdapter

tools/acceptance/cases/i031.py

### acceptanceCommand

python tools/acceptance/run_task.py I-031 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-031.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-031@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-032 · 动态PlanGraph与持久调度

### id

I-032

### title

动态PlanGraph与持久调度

### phase

B

### spec

- 10c
- 10i

### hardDeps

- I-031

### gates



### scope

含扩图/replan/fanout/fanin/mapreduce/lease；不在手机内存托管云长job。

### steps

类型化编译→预算界限→ready调度→checkpoint重放→compensation。

### deliverable

PlanCompiler/DurableScheduler与SQLite事务。

### acceptance

图环/越namespace拒绝；fanout/迭代不越上限；过期fence不提交；100重启无重复副作用；手动锁始终有效。

### profile

DEV-PURE：fake worker与SQLite。

### decision

不可补偿付费副作用标已发生待对账，不伪回滚。

### effort

3–5人日估计

### paths

packages/studio_harness/lib/{plan,scheduler}.dart；test/harness/dag_recovery/

### kind

I

### status

planned

### rowOrder

58

### entryFile

packages/studio_harness/lib/scheduler.dart

### acceptanceAdapter

tools/acceptance/cases/i032.py

### acceptanceCommand

python tools/acceptance/run_task.py I-032 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-032.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-032@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-033 · 审批/预算预留/unknown扣费对账

### id

I-033

### title

审批/预算预留/unknown扣费对账

### phase

B

### spec

- 1c
- 10d
- 12c

### hardDeps

- I-031
- I-003

### gates



### scope

含prompt/resource/revision绑定、receipt/outbox；不代表许可grant。

### steps

审批摘要hash→预留→单次提交→unknown轮询→settle/释放。

### deliverable

ApprovalService/BudgetLedger/SubmissionReconciler。

### acceptance

同幂等键最多1次POST；unknown不盲重试；取消晚到只结算不挂时间线；费用/上传/肖像同意不能被许可warning豁免。

### profile

DEV：合成供应商状态/报价；真实钱/API一律另批。

### decision

预算耗尽暂停；绑定变化审批失效，不自动加额度。

### effort

3–5人日估计

### paths

packages/studio_harness/lib/{approval,budget,reconcile}.dart；test/billing/unknown/

### kind

I

### status

planned

### rowOrder

59

### entryFile

packages/studio_harness/lib/reconcile.dart

### acceptanceAdapter

tools/acceptance/cases/i033.py

### acceptanceCommand

python tools/acceptance/run_task.py I-033 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-033.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-033@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-034 · 异构Agent通信与工件交接

### id

I-034

### title

异构Agent通信与工件交接

### phase

B

### spec

- 10e
- 10i
- 11

### hardDeps

- I-032
- I-033

### gates

- V-008=agent-model-profile

### scope

含导演/视觉/剪辑角色与不同模型Provider；不要求两模型同时驻手机。

### steps

冻结snapshot→ArtifactRef handoff→仲裁→父子预算/删除屏障。

### deliverable

AgentMailbox/RolePolicy/ConflictResolution。

### acceptance

两个不同modelId/权重包在同案例有真实记录（仅同底模改温度/量化不算）；fake仅测协议；冲突不直接写DB；争论超界暂停。

### profile

DEV先fake；真实本地/云各有V profile和单独审批。

### decision

无第二模型资格时交接标未验证，不伪称多Agent已实跑。

### effort

3–5人日估计

### paths

packages/studio_harness/lib/{mailbox,roles}.dart；test/agents/handoff/

### kind

I

### status

planned

### rowOrder

60

### entryFile

packages/studio_harness/lib/mailbox.dart

### acceptanceAdapter

tools/acceptance/cases/i034.py

### acceptanceCommand

python tools/acceptance/run_task.py I-034 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-034.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-034@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-035 · 影视QA与最小修复闭环

### id

I-035

### title

影视QA与最小修复闭环

### phase

B

### spec

- 10f
- 10i
- 8b

### hardDeps

- I-032
- I-033

### gates

- V-020=qa

### scope

含规则/模型/人工分层、unknown、最小子图；不承诺零修改成片。

### steps

候选QA→证据定位→repairPlan→预算/锁检查→复检回滚。

### deliverable

QAService/RepairPlanner与审片UI。

### acceptance

已正确镜头重新付费生成=0；锁字幕改动=0；低置信不自动通过；修复次数/付费不超批准上限。

### profile

DEV＋EVAL：标签fixture；真实模型判断另测。

### decision

定位不明转人工，不靠LLM自评分无限循环。

### effort

3–5人日估计

### paths

packages/studio_quality/lib/{qa,repair}.dart；test/quality/repair_scope/

### kind

I

### status

planned

### rowOrder

61

### entryFile

packages/studio_quality/lib/repair.dart

### acceptanceAdapter

tools/acceptance/cases/i035.py

### acceptanceCommand

python tools/acceptance/run_task.py I-035 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-035.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-035@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-036 · 角色CharacterPack/Voice/Rights资产库

### id

I-036

### title

角色CharacterPack/Voice/Rights资产库

### phase

B

### spec

- 8e
- 8g
- 8s

### hardDeps

- I-004
- I-003

### gates



### scope

含外观/视角图/LookVariant/模型绑定/授权/版本冻结；不承诺LoRA跨底模或绝对身份锁。

### steps

闭合Schema/DDL→库版本→项目pin/局部换装→@引用→撤销失效。

### deliverable

CharacterRepository/PortraitRightsRecord与导入导出。

### acceptance

全局升级不改旧项目pin；撤销后新生成/缓存命中=0；手调剪辑字幕不覆盖；跨App权限独立。

### profile

DEV-PURE：虚构角色与合成授权记录。

### decision

缺外部肖像授权仍是同意门禁，不受商业模型许可放行覆盖。

### effort

3–5人日估计

### paths

packages/studio_assets/lib/character/；test/assets/character_versions/

### kind

I

### status

planned

### rowOrder

62

### entryFile

packages/studio_assets/lib/character/character_repository.dart

### acceptanceAdapter

tools/acceptance/cases/i036.py

### acceptanceCommand

python tools/acceptance/run_task.py I-036 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-036.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-036@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-037 · 电影Craft技能/工作流包与安全编译

### id

I-037

### title

电影Craft技能/工作流包与安全编译

### phase

B

### spec

- 8f
- 8g
- 10g

### hardDeps

- I-008
- I-031

### gates



### scope

统一Harness SkillPackage/EffectRegistry/PromptCompiler；不另造可执行脚本提权。

### steps

版本包/FTS→按需召回→软摄影建议/硬EditCommand分流→预览undo。

### deliverable

CraftRegistry/SkillCompiler与签名Schema校验。

### acceptance

未注册技法显式拒；J/L cut/handles命令golden；SOFT_CAMERA_CONTROL告警；外部技能不能提权/绕审批。

### profile

DEV-PURE：自拟运镜/转场配方，不复制流行模板素材。

### decision

未知效果保留只读或替代提案；版本冻结进工程闭包。

### effort

3–5人日估计

### paths

packages/studio_assets/lib/craft/；test/skills/compile_safety/

### kind

I

### status

planned

### rowOrder

63

### entryFile

packages/studio_assets/lib/craft/skill_compiler.dart

### acceptanceAdapter

tools/acceptance/cases/i037.py

### acceptanceCommand

python tools/acceptance/run_task.py I-037 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-037.json

### singlePersonPriority

3 AI建议

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-037@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-038 · 三轴用途/输入/玩法模板与Prompt编译

### id

I-038

### title

三轴用途/输入/玩法模板与Prompt编译

### phase

D

### spec

- 8
- 8h
- 8j
- 8k
- 8l
- 8m
- 8n

### hardDeps

- I-028
- I-036
- I-037

### gates



### scope

含营销/展示/故事/素材/脚本、I2V/首尾/续写及4玩法；不互斥塞一个enum。

### steps

Brief表单→槽位/事实/安全校验→层级prompt→Provider参数能力映射。

### deliverable

WorkflowCompiler/PlayRecipeRegistry/FactLedger。

### acceptance

所有垂类至少1合法+1非法fixture；商品事实只取确认来源；未授权人物/未支持首尾模式不提交；override/template冲突不静默覆盖。

### profile

DEV-PURE：合成商品/人物/脚本/素材，不付费生成。

### decision

不支持参数不截断；固定seed不冒称跨模型一致。

### effort

4–6人日/完整模板合同估计

### paths

packages/studio_vertical/lib/；test/vertical/all_scenarios/

### kind

I

### status

planned

### rowOrder

64

### entryFile

packages/studio_vertical/lib/workflow_compiler.dart

### acceptanceAdapter

tools/acceptance/cases/i038.py

### acceptanceCommand

python tools/acceptance/run_task.py I-038 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-038.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-038@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-039 · 逐镜策略与有声animatic审批

### id

I-039

### title

逐镜策略与有声animatic审批

### phase

D

### spec

- 8b
- 8c
- 8v
- 8w
- 8x

### hardDeps

- I-038
- I-010
- I-009
- I-025

### gates

- V-020=narrative-qa

### scope

含brief→剧本/分镜/bible→静帧/2D/分层2.5D/微动/全动态；不固定70/30。

### steps

规划镜头→参考/角色pin→量台词时长→本地预演→锁片/报价审批。

### deliverable

ShotExecutionPlan/AnimaticBuilder与导演工作台。

### acceptance

15秒4镜总长准确；改主角/删镜只失效依赖；2.5D缺mask/depth/补背景明确降级；未选TTS不假有配音。

### profile

DEV：静态+自拟音频先行；TTS/生成各有门禁。

### decision

预演未确认不投昂贵生成；原生fps→24fps按PTS重采样不变速。

### effort

3–5人日/基础闭环估计

### paths

packages/studio_vertical/lib/shot_strategy.dart；integration_test/animatic/

### kind

I

### status

planned

### rowOrder

65

### entryFile

packages/studio_vertical/lib/shot_strategy.dart

### acceptanceAdapter

tools/acceptance/cases/i039.py

### acceptanceCommand

python tools/acceptance/run_task.py I-039 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-039.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-039@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-040 · 生成Provider异步候选与多镜入NLE

### id

I-040

### title

生成Provider异步候选与多镜入NLE

### phase

D

### spec

- 8
- 8i
- 8k
- 8m
- 9

### hardDeps

- I-032
- I-033
- I-038

### gates

- V-019=video-mode

### scope

含先接一个所选Profile、能力参数/quote/cancel/poll；不自动接账号。

### steps

compiled prompt→审批→submit/outbox→QA candidate→选取EditProposal。

### deliverable

VideoGenerationProvider/CandidateStore/Provenance。

### acceptance

重复/晚到/取消/unknown用例无重复计费；一镜/多镜插入可编辑clip非只扁平MP4；原音/字幕手改锁保留。

### profile

DEV fake先验；真实API或自有GPU与上传/费用另批。

### decision

first-last/真extend缺能力就拒；尾帧拼接需标模拟并重批。

### effort

3–5人日/首Provider估计，其他Provider独立复制验收实例

### paths

packages/studio_generation/lib/；test/generation/async_candidates/

### kind

I

### status

planned

### rowOrder

66

### entryFile

packages/studio_generation/lib/video_generation_provider.dart

### acceptanceAdapter

tools/acceptance/cases/i040.py

### acceptanceCommand

python tools/acceptance/run_task.py I-040 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-040.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-040@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-041 · 音乐/SFX候选、分轨与节拍剪辑

### id

I-041

### title

音乐/SFX候选、分轨与节拍剪辑

### phase

D

### spec

- 8d
- 8g
- 4

### hardDeps

- I-033
- I-004
- I-009

### gates

- V-016=ACE
- V-017=SAO
- V-018=YuE2

### scope

含统一MusicProvider/StemAsset/ABC与歌词参数/BeatGrid/duck提案；各Profile独立启用。

### steps

能力编译→报价审批→audio candidate→节拍分析→NLE提案。

### deliverable

MusicProvider/AudioCandidate/BeatGrid与版权元数据。

### acceptance

ACE通过无需等YuE2；节拍吸附合成真值误差≤1sample；手调gain/锁轨不覆盖；云传输/取消晚费照账。

### profile

DEV＋MUSIC各已验Profile；无自动付费/下载。

### decision

商业许可缺口默认warning；真实不支持分轨/翻唱字段拒，不伪造能力。

### effort

3–5人日/首Provider估计，扩展分别验收

### paths

packages/studio_generation/lib/music/；test/music/beat_duck/

### kind

I

### status

planned

### rowOrder

67

### entryFile

packages/studio_generation/lib/music/music_provider.dart

### acceptanceAdapter

tools/acceptance/cases/i041.py

### acceptanceCommand

python tools/acceptance/run_task.py I-041 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-041.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-041@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-042 · ModelPack与本地Pipeline/资源租约

### id

I-042

### title

ModelPack与本地Pipeline/资源租约

### phase

C

### spec

- 8o
- 8u
- 6c

### hardDeps

- I-004
- I-003

### gates

- V-023=heavy-model-pool

### scope

含下载校验/暂停恢复/签名/runtime探测/热卸载；不在本轮下载。

### steps

Pack manifest→受批下载→hash/ABI核验→typed图→lease/cancel/checkpoint。

### deliverable

ModelStore/OnDeviceExecutor与backend registry。

### acceptance

坏签名/算子不支持不执行；无网络节点offlineOnly网络请求=0；shared分配不重复计；OS杀进程恢复不读旧指针。

### profile

DEV fake backend；真实能力由各模型V逐包资格。

### decision

unknown许可证警告不阻；真实资源不足waitingResource，不静默云。

### effort

3–5人日估计

### paths

packages/studio_ondevice/lib/；native/model_runtime/；test/runtime/packs/

### kind

I

### status

planned

### rowOrder

68

### entryFile

packages/studio_ondevice/lib/executor.dart

### acceptanceAdapter

tools/acceptance/cases/i042.py

### acceptanceCommand

python tools/acceptance/run_task.py I-042 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-042.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-042@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-043 · 本地图像智能选区与擦除UI/结果层

### id

I-043

### title

本地图像智能选区与擦除UI/结果层

### phase

C

### spec

- 8p
- 8u

### hardDeps

- I-042
- I-026

### gates

- V-011=image-erase

### scope

含点框正负/画笔/方向映射/锁mask/非破坏填充；不把二值mask当alpha matting。

### steps

输入逆映射→模型mask→修边/ROI→本地填充→结果layer候选。

### deliverable

MaskAsset/EraseLayer与预览撤销。

### acceptance

8种方向/裁剪padding往返误差≤0.5源像素；原件不变；人工锁mask不被再推理覆盖；接受1次事务可undo。

### profile

IMAGE-AI：已验本地Pack，测试图非用户照片。

### decision

语义选区无grounding明确不支持；智能包未过不冒充经典inpaint。

### effort

3–5人日估计

### paths

packages/studio_image_editor/erase/；test/mask/geometry_locks/

### kind

I

### status

planned

### rowOrder

69

### entryFile

packages/studio_image_editor/lib/erase/erase_layer.dart

### acceptanceAdapter

tools/acceptance/cases/i043.py

### acceptanceCommand

python tools/acceptance/run_task.py I-043 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-043.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-043@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-044 · 视频对象mask追踪与人工纠正

### id

I-044

### title

视频对象mask追踪与人工纠正

### phase

D

### spec

- 8q
- 8u
- 3

### hardDeps

- I-042
- I-021

### gates

- V-012=tracking

### scope

含sourcePTS/memory checkpoint/多对象/遮挡与切镜；不按剪辑后帧号追源。

### steps

源range→传播→置信UI→锁关键帧→前后分块重追。

### deliverable

MaskTrack/TrackChunk与纠正工作台。

### acceptance

VFR+变速下全部mask引用源PTS；切镜重置；关键帧修正只失效相关块；对象丢失转waitingCorrection。

### profile

TRACK：手机轻或桌面SAM2已验Profile。

### decision

bbox/flow与memory类型如实标注；不覆盖人工修正。

### effort

3–5人日/首追踪器估计

### paths

packages/studio_video_tools/tracking/；test/video/source_pts_masks/

### kind

I

### status

planned

### rowOrder

70

### entryFile

packages/studio_video_tools/lib/tracking/mask_track.dart

### acceptanceAdapter

tools/acceptance/cases/i044.py

### acceptanceCommand

python tools/acceptance/run_task.py I-044 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-044.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-044@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-045 · 本地时序去物体与候选合成

### id

I-045

### title

本地时序去物体与候选合成

### phase

D

### spec

- 8q
- 8u

### hardDeps

- I-044
- I-043

### gates

- V-012=temporal-inpaint

### scope

含时序模型块/重叠/推断区域/原件无损；不把逐帧LaMa说成稳定全补全。

### steps

跟踪mask→上下文/flow→分块填充→接缝QA→NLE候选layer。

### deliverable

VideoEraseCandidate与coverage/provenance。

### acceptance

锁mask/字幕不变；中断从最近有效chunk续；推断区域标记；10段时序QA达V-012否则不得自动接受。

### profile

TRACK-HEAVY：仅已有合格本地Profile；无GPU不租云。

### decision

高级补全无合格包就待适配；近静态重建替代需用户明确同意。

### effort

4–6人日/首模型估计

### paths

packages/studio_video_tools/erase/；test/video/temporal_candidate/

### kind

I

### status

planned

### rowOrder

71

### entryFile

packages/studio_video_tools/lib/erase/video_erase_candidate.dart

### acceptanceAdapter

tools/acceptance/cases/i045.py

### acceptanceCommand

python tools/acceptance/run_task.py I-045 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-045.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-045@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-046 · 本地ASR/VAD字幕提案

### id

I-046

### title

本地ASR/VAD字幕提案

### phase

C

### spec

- 8r
- 8a
- 10a

### hardDeps

- I-042
- I-010

### gates

- V-009=asr

### scope

含16k/窗口去重/source-timeMap/cue候选；不默认分离或diarization。

### steps

选择源/可选预处理→分窗转写→证据/时码→diff接受。

### deliverable

TranscriptionJob/CaptionProposal与离线恢复。

### acceptance

静音/音乐疑似幻觉不自动接受；手改cue不可覆盖；窗口重叠去重；删源/取消晚到不挂cue。

### profile

SMALL-AI：已验Whisper base包。

### decision

质量不达可人工编辑字幕，不能自动上云补识别。

### effort

2–4人日估计

### paths

packages/studio_audio_tools/asr/；test/asr/caption_locks/

### kind

I

### status

planned

### rowOrder

72

### entryFile

packages/studio_audio_tools/lib/asr/transcription_job.dart

### acceptanceAdapter

tools/acceptance/cases/i046.py

### acceptanceCommand

python tools/acceptance/run_task.py I-046 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-046.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-046@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-047 · 分离stems/语音降噪派生资产

### id

I-047

### title

分离stems/语音降噪派生资产

### phase

C

### spec

- 8r
- 8u

### hardDeps

- I-042
- I-009

### gates

- V-010=audio-restore

### scope

含RNNoise/进阶包各适配、OLA/延迟/声道；不覆盖原音。

### steps

预览短选区→分离/降噪→残差QC→stems入库→混音提案。

### deliverable

AudioDerivedCandidate与stem provenance。

### acceptance

重建/clip/延迟达V-010；100次取消State释放；更换预处理失效ASR缓存但不改已锁字幕。

### profile

AUDIO：按Profile逐包开，不要求手机重分离。

### decision

本地资源不足只暂停/降档提案；原音可继续编辑。

### effort

3–5人日/首组合估计

### paths

packages/studio_audio_tools/restore/；test/audio/stems_ola/

### kind

I

### status

planned

### rowOrder

73

### entryFile

packages/studio_audio_tools/lib/restore/audio_candidate.dart

### acceptanceAdapter

tools/acceptance/cases/i047.py

### acceptanceCommand

python tools/acceptance/run_task.py I-047 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-047.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-047@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-048 · 超清/画面降噪与视频编码整合

### id

I-048

### title

超清/画面降噪与视频编码整合

### phase

C

### spec

- 8t
- 8u
- 7

### hardDeps

- I-042
- I-026
- I-024

### gates

- V-013=upscale-denoise

### scope

含tile/halo/方向/crop与选区视频；不默认生成的细节为真实。

### steps

图像分块→拼接→短视频逐PTS→QC/编码→非破坏候选。

### deliverable

RestoreImageJob与视频派生asset。

### acceptance

接缝/闪烁达V-013；native倍率与输出预设明确；OS暂停可恢复；水印/文字警告不丢；无全片驻RAM。

### profile

IMAGE-AI：合格ncnn/其他固定包与媒体profile。

### decision

图片通过可独立开；视频未过不借图片资格放行。

### effort

3–5人日估计

### paths

packages/studio_image_tools/restore/；test/upscale/tiles_encode/

### kind

I

### status

planned

### rowOrder

74

### entryFile

packages/studio_image_tools/lib/restore/restore_image_job.dart

### acceptanceAdapter

tools/acceptance/cases/i048.py

### acceptanceCommand

python tools/acceptance/run_task.py I-048 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-048.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-048@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-049 · 本地朗读/台词与角色声线引用

### id

I-049

### title

本地朗读/台词与角色声线引用

### phase

C

### spec

- 8s
- 8e

### hardDeps

- I-042
- I-009
- I-036

### gates

- V-014=tts

### scope

含文本分句/音素/速度/声线pin/24k重采样；不把TTS当唱歌。

### steps

台词规范化→frontend→逐句音频→时长对齐→NLE对白候选。

### deliverable

SpeechJob/VoiceProfile与台词diff。

### acceptance

未知字音可修正；句段时间和PCM拼接正确；改台词只失效对应句与节奏依赖；手调clip/字幕锁保留。

### profile

VOICE：合格Kokoro或明确选择的已下载OS voice。

### decision

无离线voice不能宣传离线；云TTS另授权，不能静默替代。

### effort

3–5人日/首语言估计

### paths

packages/studio_audio_tools/tts/；test/tts/dialogue_timing/

### kind

I

### status

planned

### rowOrder

75

### entryFile

packages/studio_audio_tools/lib/tts/speech_job.dart

### acceptanceAdapter

tools/acceptance/cases/i049.py

### acceptanceCommand

python tools/acceptance/run_task.py I-049 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-049.json

### singlePersonPriority

4 按需端侧

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-049@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-050 · 合意音色克隆与embedding生命周期

### id

I-050

### title

合意音色克隆与embedding生命周期

### phase

D

### spec

- 8s
- 8e
- 10a

### hardDeps

- I-049
- I-036

### gates

- V-015=voice-clone

### scope

含授权普通真人克隆/加密/撤销传播；不做欺诈冒充，不一刀切禁真人。

### steps

参考验证/同意→embedding加密→克隆→引用失效/撤销清理。

### deliverable

CloneJob/ConsentRef与安全voice store。

### acceptance

无同意/撤销后新执行=0；embedding不进普通archive/log；台词改变不覆盖旧已选音频；所有新引用可追溯。

### profile

VOICE-GPU：合格桌面Profile，手机仅实验。

### decision

质量/资源不足标待适配；不要用F5等底层NC事实偷偷作为项目硬阻断。

### effort

3–5人日估计

### paths

packages/studio_audio_tools/clone/；test/voice/consent_lifecycle/

### kind

I

### status

planned

### rowOrder

76

### entryFile

packages/studio_audio_tools/lib/clone/clone_job.dart

### acceptanceAdapter

tools/acceptance/cases/i050.py

### acceptanceCommand

python tools/acceptance/run_task.py I-050 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-050.json

### singlePersonPriority

5 专业生成

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-050@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-051 · 可选业务API/鉴权/对象直传

### id

I-051

### title

可选业务API/鉴权/对象直传

### phase

E

### spec

- 10h
- 12
- 12b

### hardDeps

- I-033
- I-003

### gates

- V-021=serverless

### scope

含单后端/auth/tenant/短期签名URL；不选定或部署供应商。

### steps

统一Job API→对象直传→ACL/配额→本地实现与contract tests。

### deliverable

GatewayPorts与可选服务端模块。

### acceptance

业务函数不转发大媒体；越tenant访问=0；URL过期/重用规则可测；密钥不入App/工程；上传必有同意。

### profile

BACKEND：本地模拟先行；真实云/对象存储和费用另批。

### decision

未启云时App纯本地仍运行；不能借serverless自动获取用户素材。

### effort

3–5人日估计

### paths

services/generation_gateway/{api,auth,uploads}/；test/backend/acl/

### kind

I

### status

planned

### rowOrder

77

### entryFile

services/generation_gateway/api/main.py

### acceptanceAdapter

tools/acceptance/cases/i051.py

### acceptanceCommand

python tools/acceptance/run_task.py I-051 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-051.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-051@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-052 · 可选持久队列/GPU worker/回调接管

### id

I-052

### title

可选持久队列/GPU worker/回调接管

### phase

E

### spec

- 10h
- 10c
- 10d

### hardDeps

- I-051
- I-032
- I-040

### gates

- V-021=serverless

### scope

含DB/outbox/lease/队列/worker、手机休眠后云job接管；不先拆微服务集群。

### steps

持久提交→worker租约→provider轮询/回调→去重settle→客户端重连。

### deliverable

AsyncJobService、worker协议及自有GPU接入。

### acceptance

100乱序/重复回调仅1次入库与结算；unknown不重POST；手机断开任务不丢；公平配额不跨tenant饥饿。

### profile

BACKEND：local worker模拟；GPU可为自有电脑，远端执行另审批。

### decision

部署未批保持planned；OS取消不等供应商停费，晚到对账保留。

### effort

3–5人日/首执行器估计

### paths

services/generation_gateway/{jobs,outbox,worker}/；test/backend/handoff/

### kind

I

### status

planned

### rowOrder

78

### entryFile

services/generation_gateway/worker/worker.py

### acceptanceAdapter

tools/acceptance/cases/i052.py

### acceptanceCommand

python tools/acceptance/run_task.py I-052 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-052.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-052@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-053 · 支付权益/积分/地区发行配置

### id

I-053

### title

支付权益/积分/地区发行配置

### phase

E

### spec

- 12c
- 1a
- 1c
- 10d

### hardDeps

- I-033

### gates

- V-022=store-billing

### scope

含StoreKit/Play及离线权益缓存、退款撤销、产品地区配置；不默认国内支付供应商。

### steps

ReceiptPort→服务端验证接口→唯一交付→退款/恢复购买→定价披露。

### deliverable

EntitlementLedger/AppReleaseProfile与沙盒用例。

### acceptance

重复receipt=1次发放；离线不能凭客户端伪造新增额度；退款/撤销不再新发；云费用不从本地许可warning豁免。

### profile

RELEASE：已有账号沙盒；注册/内购/提审均不在本轮执行。

### decision

无法验证权益就受限，不绕平台拒绝；许可风险与平台审核事实分开。

### effort

3–5人日/首商店估计

### paths

packages/studio_billing/；services/receipt_verifier/；test/billing/entitlements/

### kind

I

### status

planned

### rowOrder

79

### entryFile

packages/studio_billing/lib/entitlement_ledger.dart

### acceptanceAdapter

tools/acceptance/cases/i053.py

### acceptanceCommand

python tools/acceptance/run_task.py I-053 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-053.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-053@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-054 · 隐私/权限/导出删除与地区网络策略

### id

I-054

### title

隐私/权限/导出删除与地区网络策略

### phase

E

### spec

- 12b
- 10a
- 1c
- 5d

### hardDeps

- I-027
- I-028
- I-003

### gates



### scope

含云上传同意、权限撤销、删除屏障/导出脱敏；不保证provider远端彻底删除。

### steps

PermissionBroker→数据映射→用户删除/导出→network allowlist与地区Profile。

### deliverable

PrivacyService与数据保留清单。

### acceptance

拒绝照片/麦克风仍可文件导入编辑；删除内容在FTS/RAG/summary/archive不可复活；默认诊断不含私文/素材。

### profile

DEV：合成内容；政策事实/地区适用性由V-022核验。

### decision

缺系统权限真实阻断相应动作，不绕过；旧摘要不可复活。

### effort

3–5人日估计

### paths

packages/studio_privacy/；test/privacy/delete_export/

### kind

I

### status

planned

### rowOrder

80

### entryFile

packages/studio_privacy/lib/privacy_service.dart

### acceptanceAdapter

tools/acceptance/cases/i054.py

### acceptanceCommand

python tools/acceptance/run_task.py I-054 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-054.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-054@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-055 · 多语言/RTL/无障碍替代操作

### id

I-055

### title

多语言/RTL/无障碍替代操作

### phase

E

### spec

- 12d
- 9
- 3

### hardDeps

- I-025
- I-026
- I-010

### gates



### scope

含本地化/动态字号/键盘/读屏/时间线列表替代；不把文本翻译当完整可及性。

### steps

提取字符串→RTL/字体→焦点/快捷键→读屏完成基础闭环。

### deliverable

LocaleBundle/AccessibilityActionMap与审计表。

### acceptance

中英/RTL测试无截断关键动作；无拖拽也能split/trim/save/export；200%字号与键盘焦点顺序可用。

### profile

UI：现有P0辅助功能工具；另平台逐验，非模拟器冒真机。

### decision

关键阻断修复后发布；个别语言质量未验不宣传。

### effort

3–5人日/基础语言组估计

### paths

packages/studio_editor_ui/l10n/；integration_test/accessibility/

### kind

I

### status

planned

### rowOrder

81

### entryFile

packages/studio_editor_ui/lib/l10n/accessibility_actions.dart

### acceptanceAdapter

tools/acceptance/cases/i055.py

### acceptanceCommand

python tools/acceptance/run_task.py I-055 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-055.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-055@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-056 · 脱敏观测/trace/诊断与成本看板

### id

I-056

### title

脱敏观测/trace/诊断与成本看板

### phase

E

### spec

- 10h
- 12d
- 12e

### hardDeps

- I-003
- I-031

### gates



### scope

含本地trace/run/job/费用关联和用户可导出诊断；不默认上传日志。

### steps

事件规范→脱敏→本地trace viewer→可选metrics/告警。

### deliverable

DiagnosticsPort/TraceViewer与run成本统计。

### acceptance

密钥/正文/embedding/原图hash可识别策略按隐私配置过滤；故障trace可串联revision/job；重复事件不重复计成本。

### profile

DEV：合成trace，无观测服务开通。

### decision

外发诊断必须用户明确同意；无遥测后端不阻本地功能。

### effort

2–4人日估计

### paths

packages/studio_quality/lib/trace_viewer.dart；test/observability/redaction/

### kind

I

### status

planned

### rowOrder

82

### entryFile

packages/studio_quality/lib/trace_viewer.dart

### acceptanceAdapter

tools/acceptance/cases/i056.py

### acceptanceCommand

python tools/acceptance/run_task.py I-056 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-056.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-056@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-057 · Prompt/Skill评估、AB候选与受控发布

### id

I-057

### title

Prompt/Skill评估、AB候选与受控发布

### phase

E

### spec

- 10g
- 12e
- 13a
- 13b

### hardDeps

- I-035
- I-037
- I-038

### gates

- V-020=eval-baseline

### scope

含fixture/AB显式同意/灰度回滚；SFT/DPO/RLHF仅另行实验合同，不自动训练。

### steps

版本registry→离线held-out→指标/成本比较→签署候选→回滚。

### deliverable

EvalRunner/ReleaseManifest与可选训练ADR。

### acceptance

生产包不能自我提权；用户内容无同意进训练/AB=0；unknown分数不赢；回滚保旧工程skill pin；无真实训练不报模型改善。

### profile

EVAL：先离线合成；模型/训练费用和数据许可另批。

### decision

不过阈值保旧版本；实验ADR不是训练已实现或已执行。

### effort

3–5人日估计

### paths

packages/studio_quality/eval/；tools/research/training_contract/；test/eval/releases/

### kind

I

### status

planned

### rowOrder

83

### entryFile

packages/studio_quality/lib/eval/eval_runner.dart

### acceptanceAdapter

tools/acceptance/cases/i057.py

### acceptanceCommand

python tools/acceptance/run_task.py I-057 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-057.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-057@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-058 · 跨端多App发布资格与端到端回归

### id

I-058

### title

跨端多App发布资格与端到端回归

### phase

E

### spec

- 6d
- 10j
- 12
- 13
- 13a
- 13b
- 14

### hardDeps

- I-014
- I-024
- I-054
- I-055
- I-056

### gates

- V-022=public-release

### scope

含版本/feature matrix、签名/SBOM/商店资料与回归；不强制全部可选能力上线。

### steps

选发行Profile→跑真实端到端→核权限/费用/许可证事实→签署发布候选。

### deliverable

ReleaseEvidenceBundle和未验证功能清单。

### acceptance

已启用feature真实fixture全过；离线双App隔离；durable编辑零丢；未验能力不显示已支持；付费发行须另满足I-053。

### profile

RELEASE：仅已批准环境/账号；构建/提审在未来任务中单独授权。

### decision

真实安全/平台拒绝no-go；纯商业许可缺口warning不改为此任务硬阻。

### effort

3–5人日/首发行Profile估计，审核等待另计

### paths

tools/release/qualify/；integration_test/release_profiles/

### kind

I

### status

planned

### rowOrder

84

### entryFile

tools/release/qualify/run_qualification.py

### acceptanceAdapter

tools/acceptance/cases/i058.py

### acceptanceCommand

python tools/acceptance/run_task.py I-058 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-058.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-058@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-059 · 条件HDR/高级调色能力实现

### id

I-059

### title

条件HDR/高级调色能力实现

### phase

E

### spec

- 4
- 4b
- 7a

### hardDeps

- I-022
- I-024

### gates

- V-006=advanced-color

### scope

含已冻结色彩管线/LUT/tonemap；不扩大到未设计调色面板全集。

### steps

按ADR注册节点→CPU/GPU→色彩metadata→预览/导出一致。

### deliverable

ColorEffectsPack与HDR ExportProfile。

### acceptance

通过V-006数值/观感各自资格；无HDR硬件不标观感实测；缺功能保原参数只读；变更tonemap要用户确认。

### profile

HDR：已验GPU/屏；无设备保planned，不要求采购。

### decision

no-go保持SDR主线，HDR原件不得静默破坏。

### effort

3–5人日/首管线估计

### paths

native/studio_media/color/；test/color/hdr_export/

### kind

I

### status

planned

### rowOrder

85

### entryFile

native/studio_media/color/color_pipeline.cpp

### acceptanceAdapter

tools/acceptance/cases/i059.py

### acceptanceCommand

python tools/acceptance/run_task.py I-059 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-059.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-059@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-060 · 条件limiter/响度DSP执行节点

### id

I-060

### title

条件limiter/响度DSP执行节点

### phase

E

### spec

- 4
- 7

### hardDeps

- I-009
- I-023

### gates

- V-024=advanced-dsp

### scope

只实现ADR已定limiter/响度preset；不提前选未经验证DSP。

### steps

注册参数/延迟→lookahead/state→flush→混音输出。

### deliverable

AudioDSPRegistry节点与延迟补偿。

### acceptance

truepeak/长度达到V-024；同图预览/导出算法一致；preset改变可undo；手调音量不被分析改写。

### profile

DSP：CPU本地Profile；依赖许可缺口warning保留。

### decision

未通过不启高级DSP，基础混音继续。

### effort

2–4人日估计

### paths

native/studio_media/audio_dsp/；test/audio/limiter_export/

### kind

I

### status

planned

### rowOrder

86

### entryFile

native/studio_media/audio_dsp/limiter.cpp

### acceptanceAdapter

tools/acceptance/cases/i060.py

### acceptanceCommand

python tools/acceptance/run_task.py I-060 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-060.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-060@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e

## I-061 · 条件glTF受限预览与资产引用

### id

I-061

### title

条件glTF受限预览与资产引用

### phase

E

### spec

- 4a
- 12

### hardDeps

- I-026
- I-022

### gates

- V-026=gltf-preview

### scope

只做受限glTF预览/变换/图层引用；NeRF/3DGS训练编辑继续延期另拆。

### steps

按ADR适配→无外网读取→图层渲染→冻结依赖归档。

### deliverable

Preview3DPort与feature声明。

### acceptance

V-026安全/预览fixture通过；未支持扩展不静默丢；归档不拉外链；未纳入版本则任务保持planned而非写ADR充实现。

### profile

3D：已有GPU与已验库；无需先买设备。

### decision

未验库/资源就不启此feature，不牵连图像/NLE/生成。

### effort

3–5人日/受限预览估计

### paths

packages/studio_graphics_3d/；test/graphics/gltf_preview/

### kind

I

### status

planned

### rowOrder

87

### entryFile

packages/studio_graphics_3d/lib/preview_3d_port.dart

### acceptanceAdapter

tools/acceptance/cases/i061.py

### acceptanceCommand

python tools/acceptance/run_task.py I-061 --profile <FROZEN_PROFILE> --report artifacts/acceptance/I-061.json

### singlePersonPriority

6 条件选配/发行

### parallelRule

硬前置输出稳定后可与无读写/设备资源冲突任务并行；单人不据此缩短日历估计。

### instanceKeyTemplate

I-061@AppProfileVersion@DeviceRuntimeModelFingerprint@Capability

### pathsVerifiedInUserRepo

False

### specBaselineHash

6d37bf4e15a58d82fb545be9e908e2d28c3dd3dac7cbb66757878a4a123b064e
