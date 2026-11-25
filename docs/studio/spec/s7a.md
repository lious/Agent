## 7A · 图编译、解码时钟与硬件帧所有权

```text
// 以下是本次确定的运行期合同/伪代码，不声称已编译的C++头文件。
// packages/studio_document/render_recipe_compiler.dart
RenderRecipeCompiler.freeze(snapshotHash, sequenceId, range, resourceBindings,
                            capabilities, quality) -> LogicalRecipe
// 只导出所需闭包/固定版本/Q映射，不按每帧展开JSON，不移动GPU像素到Dart。
// native/studio_media/{graph_compiler,source_session,codec_adapter,frame_lease}.h
AssetBinding {assetId,assetVersion,blobHash,fileToken,streamIndex,
 commonOriginQ,editListMapHash,ptsIndexHash,proxyMapHash,color,orientation}
GraphNode {id,kind,inputs[],localRange,timeMapRef,parameters,
 outputExtent,pixelFormat,color,alphaMode,implementationVersion}
ExecutionPlan {logicalHash,mode:preview|export,deviceEpoch,nodes[],edges[],
 sourceSessions[],resourceReservations[],fallbackPolicy,cacheNamespace}
GraphCompiler.lower(LogicalRecipe, CapabilityReport, Mode) -> ExecutionPlan
SourceSession.open(AssetBinding,DecodeConfig,CancelEpoch) -> SourceSessionId
SourceSession.seek(Q sourceTime,seekGeneration) -> Pending|ExactFrameLease|Error
SourceSession.pull(Q sourceTime) -> FrameLease|WouldBlock|EndOfSource|Error
CodecAdapter.encode(RenderedFrameLease,CodecConfig) -> EncodedPacket[]|WouldBlock
CodecAdapter.drain() -> EncodedPacket[]|Drained|Error
EncodedPacket {refcountedAVPacket,streamKey,timeBase,pts,dts,duration,
 keyFlag,codecConfigEpoch,skipSamples,discardPadding}
FrameLease {id,engineId,deviceEpoch,recipeHash,seekGeneration,sourceBindingHash,
 ptsQ,durationQ,formatEpoch,extent,pixelFormat,color,alphaMode,orientation,
 memoryKind,nativePayload,readFence,releaseExecutor,consumerRefs}
AudioSink.presentation() -> {contentSamplesPresented,hostTimeNs,latencySamples,
 deviceEpoch,estimated} // 已做一次延迟校准，调用方不能再减一次latency
AudioSink.write(Float32Block) -> acceptedSamples|WouldBlock|DeviceLost
CapabilityReport {ffmpegBuildId,osBuild,gpuId,driver,deviceEpoch,codecName,
 direction,codecId,profile,level,extent,bitDepth,pixelFormats[],hwFrameTypes[],
 actualHardware,textureImport,encodeSurface,transferFormats[],maxSessions,
 warmupResult,copyPlan,denylistReason}
// FrameLease/nativePayload只存在进程内，不写Project JSON、日志或会话上下文。
// Event元数据/命令通过FFI；Flutter textureId由平台Presenter注册，Dart不解引用AVFrame。

```

FFI边界只传有size/ABI version的结构、受限recipe bytes、opaque handle和事件元数据。studio_probe结果必须由studio_free_result释放；Dart不能用自己的allocator释放AVFrame/AVPacket/FFmpeg内存。FrameLease最后一个consumer先等read/write fence，再把av_frame_unref/codec buffer归还派发到releaseExecutor，不从Flutter绘制线程关闭codec。begin_close期间仍允许已持有lease归还；超时报告持有者，不能强free。资源硬上限（maxDecodeSessions/maxEncodeSessions/maxCpuDecodeThreads/gpuBytes/packetBytes/cacheBytes）由EngineConfig必填，SourceSession向进程内arbiter申请，不让FFmpeg默认auto线程数与多个本地模型无限争抢。

| 文件/步骤 | 确定性实现、前置与输出 | 失败/断言 |
| --- | --- | --- |
| graph_compiler.cpp::lower | 冻结当前sequence/source版本→解析retainedSources→展开可见轨/转场源/字幕/Bus→生成有理时间segment和有向无环节点→按设备选物理kernel/CPU转换→预算→分配会话。Dart与native使用相同Q/TimeMap goldens，native精确控制运算用BigInt；GPU只收当前帧Float32 uniforms。 | 字段/哈希/缺资源/未知效果先拒绝，不让FFmpeg猜工程。render hash包含compiler、色彩LUT、字体/glyph、effect、源绑定、shader、质量；不只用revision或文件名。 |
| 预览图与导出图 | 共同逻辑顺序为source/timeMap→颜色/alpha→crop/mask/transform/effects→track composite/transition→caption→output。预览下采样并用proxy map，输出到texture/audio sink；导出按每个输出帧/音频块pull原件到encoder/mux，不能取UI截图。 | 只有已记录的previewQuality可改变采样尺寸；字体、转场曲线、时间与颜色公式不变。CPU参考/GPU编码前golden比较容差，不能用编码后文件bit一致作为目标。 |
| 可选filter_graph.cpp | libavfilter默认不承担整条时间线；确有需求时按已签入FilterRegistry创建AVFilterGraph，明确buffersrc/sink像素格式、time_base、采样率与延迟，同一节点在预览/导出均可实现才放行。 | 禁任意用户filter字符串、movie/amovie取文件、shell和外部URL；无对应preview kernel时不能悄悄只在export套滤镜。filter能力/许可随build profile登记。 |
| ffmpeg_io.cpp::openToken | FileTokenRegistry验证app/tenant[box-local audit path]读写范围→打开独立fd/句柄→avio_alloc_context读/seek或写回调；支持AVSEEK_SIZE并掩码处理seek flags。格式白名单、probe字节/时限、interrupt_callback检查epoch。 | FFmpeg网络禁用；嵌套io_open仅接受注册token，不沿容器提供的路径/URL打开其他文件。EOF返回AVERROR_EOF，取消为AVERROR_EXIT，不用0假装继续读。非seekable输入先显式本地spool，磁盘不足不碰原件。 |
| source_session.cpp::open/pull | avformat_open_input/find_stream_info→copy codecpar→选decoder/hw config→avcodec_open2。每个并发consumer有独立AVFormatContext/AVCodecContext；preview/export不共用可变decoder。同一asset的A/V默认独立demux游标，避免video满队列阻塞音频。 | AVFrame/AVPacket不可跨线程共享可变容器；av_frame_ref/clone是引用而非深拷贝，队列持有自己的wrapper。Ready图像不可原位修改，参数改变创建新输出。 |
| send/receive循环 | send_packet成功才释放输入packet；EAGAIN先receive使状态前进，再重试同一packet，不能unref丢包或sleep盲等。receive循环直到EAGAIN/EOF。EOF送一次null后drain；seek后的继续解码先flush_buffers。编码使用对应send_frame/receive_packet协议。 | 一个packet可对应0..N帧，不假定1:1；send与receive同时EAGAIN视为协议错误而不是无限循环。正常EOF不等于取消，不能为取消强行mux一个成功尾部。 |
| seek_planner.cpp::seekExact | sourceAt用公共origin/edit-list/proxy PTS map映射到stream time_base；128位/BigInt检查乘除溢出，按目标覆盖区间转换，不用29.97 double。avformat_seek_file在目标之前可解码关键帧范围seek→清队列→codec线程flush→重建swr状态→按PTS解码到覆盖目标的帧。 | 关键帧seek不是精确seek；DTS用于解码顺序，不是播放位置。VFR取pts≤t<nextPTS；缺可靠PTS/duration需归一或TIMESTAMP_AMBIGUOUS，不能按nominal fps编造。每次seekGeneration递增，旧帧只归还资源不显示。 |
| frame_cache.cpp | 压缩packet cache有bytes上限；decoded LRU按blob/version/stream/sourcePTS/proxyMap/color/extent/format/deviceEpoch键；render cache另含完整recipeHash。ready帧按PTS有界保留到下一帧边界可判定。 | 硬件pool最小DPB与应用3帧队列是两件事。seek/设备丢失清旧epoch条目；仍被GPU/encoder使用的lease不可被LRU复用。硬件内存不足先降预览尺寸/代理或排队，不删用户原件。 |

| 互操作/调度 | 所有权与具体状态变化 |
| --- | --- |
| Apple | AV_PIX_FMT_VIDEOTOOLBOX帧通过受控适配取CVPixelBuffer（目标版本封装内访问data[3]），AVFrame ref负责其生存期。Metal纹理view持有到command buffer完成，encoder pool输出再持有到codec释放。只有必要时av_hwframe_transfer_data到支持的CPU格式；无支持时从压缩源切软件decoder。 |
| Android Surface | 每个decoder一次只render一个待锁存buffer；av_mediacodec_release_buffer(render=1)恰好一次→等待onFrameAvailable→GL线程updateTexImage核对timestamp→拷到自己的稳定FBO后才能render下一帧。OES纹理会被下一次update覆盖，不能直接长期缓存。取消/丢弃走render=0或已render后的安全回收，不重复release。Surface路径免CPU回读但有GPU拷贝，不称零总拷贝。 |
| Android编码桥 | GPU renderer向encoder EGLSurface提交前设presentationTimeNs，swap后输出以presentationTimeUs归一成Encoder time_base。格式改变/CSD生成完整AVCodecParameters（SPS/PPS、尺寸/profile）再写mux header；codec-config buffer不是普通画面packet，使用固定AnnexB/AVCC归一策略，拒绝缺CSD的文件。直接系统codec只替代codec，不替代FFmpeg mux。 |
| Windows/Linux | D3D11 frame必须连texture arraySlice与device一起保留；同D3D device匹配NV12且MFT接受hw_frames_ctx才走GPU输入。Linux DRM_PRIME保留各plane fd/stride/offset/modifier与fence，只有双方可import才映射EGL/VAAPI；否则标记GPU copy或CPU transfer。所有COM/fd/texture按唯一owner释放，不能拷整数句柄后双close。 |
| AudioClock与buffering | AudioSink返回已校准的contentSamplesPresented，clock=anchorQ+presented/48000；不按UI timer或已提交ring样本推进，也不重复减latency。CoreAudio/AAudio/WASAPI/PipeWire适配共同合同。设备路由变化重建epoch/anchor；underrun进入buffering，冻结内容时钟并重建队列；故障填充silence不计内容，工程Gap的silence则正常计时。 |
| 帧调度与背压 | preview clock到t后选覆盖帧；迟到超过一输出帧可丢显示，不跳参考解码、不随意删音频。mailbox只留最新帧并release替换项。export按k/fps及绝对sample边界pull，所有帧都交encoder；EAGAIN向上游传播WouldBlock。音频callback不分配/不锁DB/不调FFmpeg，提前由worker填ring。 |
| 状态/取消/设备丢失 | SourceSession:closed→opening→ready→seeking\|decoding→draining→closed，失败进failed；Job:queued→preparing→rendering→draining→muxFinalizing→verifying→publishing→succeeded，取消进cancelRequested/draining→canceled。epoch胜负由native协调器CAS；发布先赢返回ALREADY_COMMITTED。GPU/encoder引用没归还不能free，UI切会话不自动close引擎。 |
| 能力探测与fallback | Build清单→avcodec_get_hw_config/设备格式→系统profile/尺寸/并发探测→真实open+短warm-up+纹理import+编码重开probe。缓存键含OS/GPU/driver/buildId，设备重建失效。失败按候选列表最多一次重建→软件decode；encode候选必须满足同preset。VT可显式allow_sw，MF可选系统软件MFT；MediaCodec查询可用软件组件。无可用H264 encoder就ENCODER_UNAVAILABLE，不虚构FFmpeg自带免费软件H264编码器。 |
| 跨App/多模型 | AppProfile实例各有engine/recipe/lease namespace；进程内ResourceArbiter对硬件codec session、GPU纹理字节、encoder和本地模型KV发有界租约。不同App进程不能靠本SDK保证全OS互斥。导出与LLM争算力时先排队/在safe-point卸载，不以OOM为由自动上传云端；关闭A不释放B的context引用。 |

| 导出类/阶段 | 具体字段、时间基与不可省略的顺序 |
| --- | --- |
| export_scheduler.cpp::start | 冻结snapshot/source/recipe，申请磁盘与encoder租约，准备私有可seek临时文件；视频生成k=0..449，time=k/30；音频按绝对sample边界产生720000内容sample。效果lookahead记录pipelineLatencySamples并补偿，不把DSP延迟挪到成片开头；只允许编码前帧golden通过的节点。 |
| packet_normalizer.cpp | FFmpeg encoder沿用AVPacket的PTS/DTS/time_base，Android直接codec保存submitTimestampUs→canonicalFrameIndex映射，输出不能按微秒增量累加。P1配置maxBFrames=0；仅在no-reorder合同且packet验证通过时可补DTS=PTS，发现B/reordered但无可靠DTS报ENCODER_DTS_UNSUPPORTED。decoder的B帧支持与这个输出限制不同。 |
| token_mux_writer.cpp::open | avformat_alloc_output_context2(mp4)→创建自定义可seek写AVIO→解析原生CSD或avcodec_parameters_from_context填完整codecpar/extradata/global-header→avformat_write_header。实际muxer stream time_base以write_header返回后的值为准。每包用av_packet_rescale_ts(encoderTB,streamTB)并设stream_index，再av_interleaved_write_frame，按每流DTS递增检验，不按PTS排序破坏B帧顺序。 |
| faststart与受权IO | movflags=faststart的第二遍在n9.1 mux_utils.c会经s.io_open重开s.url。TokenMuxWriter设置opaque studio-token临时URL，io_open/io_close2只允许同一个导出临时token的读写重开；不能因已设自定义pb就漏开这个回调、也不能开放任意file/http协议。目标不可seek时先本地scratch后复制发布，空间不足明确DISK_FULL。 |
| finish/abort | swr null输入取尽delay→DSP补偿→音频/视频encoder分别send null、receive至EOF→写完交错packet→av_write_trailer/faststart→flush/fsync→libavformat重新probe、必要首尾decode验证→按目标文件系统能力发布。取消/错误关闭codec和自建AVIO，free当前AVIO.buffer及context，保旧正式文件；不能在取消后把.partial当成功文件。 |
| OutputVerifier | 验证450帧、单调DTS/合法PTS、High且level不高于4.1、8bit 4:2:0/Rec709、实际可听720000sample、字幕/alpha flatten、容器首尾。AAC的initial_padding与skip/discard由实际encoder/packet/mux生成，不能一律减896。header/trailer损坏、尺寸/profile被encoder忽略、音视频端点越界均阻止发布。 |

错误路径统一映射CODEC_OPEN_FAILED、HW_IMPORT_UNSUPPORTED、HW_TRANSFER_UNSUPPORTED、TIMESTAMP_AMBIGUOUS、DYNAMIC_FORMAT_UNSUPPORTED、DEVICE_LOST、ENCODER_UNAVAILABLE、AVIO_DENIED、DISK_FULL和CANCELED；保留原始AVERROR/nativeCode但日志脱敏。stride/alignment变化更新frame descriptor，真正尺寸/色彩中途改变而Asset合同无法表示时阻止并提归一副本。export中途重建encoder必须从头新attempt，不能拼接不同codecConfigEpoch。反复失败不会自动换云服务。
