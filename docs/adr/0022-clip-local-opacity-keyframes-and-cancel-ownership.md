# ADR0022 — clip-local opacity关键帧消费者与真实取消所有权

## 保留原合同

沿原 s3关键帧、s4、s5a数值/owner域、I-008、I-022/V-003，不修改104份快照或87项验收依赖。不扩数据库/指纹协议。仍仅黑色不透明背景、同尺寸CFR/1×/Rec709 limited YUV420 CPU opacity，FP32 transfer+RGB8 staging；没有冒充FP16 GPU、多轨合成、其他资源执行或物理同步。

## 时间/插值/编辑

- Keyframe.localTime 是 **clip-local project seconds**，u=t_project_frame−clip.timelineRange.start，不是source PTS。project frame由原有FPS有理数求得；精确sample API保留原有source-time查询语义；预览显式sampleFrame用呈现服务sample确认的项目时间向下选交付帧，原件采样用同一帧时间经过sourceRange/timeMap。export逐交付帧使用相同Dart求值器，一次性有界Q16 schedule交给同一个native像素节点；不在C++复制另一份插值器，不逐帧累计浮点时间。
- UI整数frame输入→精确frameTime，低层API对off-grid点显式KEYFRAME_NOT_ON_FRAME，不默默改坐标。graph也明确拒绝不在交付帧格上的视频start/duration，避免旧的export round与preview采样相位不同；可保全该数据，但不声称本切片可执行它。
- 同param/time替换保留point ID，同值/模式noop；支持scalar value、hold/linear、easing=null。α先精确有理数，最后一次Float64转换逐点插值。hold在[a,b)取a值，恰好b取b；首末区间外hold端值。owner控制域[0,duration]允许末端控制点，但可渲染域[0,duration)，UI拒绝把末端当本clip下一帧预览。
- Move不移局部点；Slip改变源不改变局部曲线。Split在切点插值：左边终点、右边0点同值，右侧重基准且effect/point IDs独立；normal/linked trim在边界插值并裁掉域外点、in端重基准，向外延伸hold裁切后边值，不偷偷恢复已裁掉的点；原历史可undo。Roll/slide沿各clip实际源入点delta/时长做同样域裁切，未声称完整交付这两种操作验收。
- 所有effect/clip/sequence变更一条事务命令，clip.effects锁也保护隐式裁切。编辑已disabled效果不自动启用；静态Apply对带曲线的效果明确拒绝，不清空关键帧。Remove只移显式时间命中的点，清空后用原base参数；首次创建效果base取首个显式点值。
- 不支持向量/其他param/插件版本/扩展/easing/效果仍明确unsupported或只读保全；不剥离内容转可写。执行上限每clip256点、每segment120000帧；SDK在分配任一schedule之前先查总交付帧≤120000，native全片非重叠segment总帧也≤120000，schedule精确长度、整数0..65536，禁止与静态scalar混用。Dart每segment只验证/排序一次，二分查相邻点；无新增无限registry。legacy adapter缺linearOpacityKeyframesV1时执行明确拒绝。

## 真正发现并修复的取消故障

新100次active-opacity取消测试在**至少2帧实际提交encoder之后**取消，而不是只取消准备阶段。首轮发生glibc `corrupted size vs. prev_size`，保留失败日志。调查到Input.at原先current=next; next=decode()，当decode的epoch检查抛CANCELED，赋值未完成，current和next仍指同一AVFrame；析构double-free。改为std::exchange(next,nullptr)转移所有权后再调用可抛异常的decode。

加轻量application-owned AVFrame alloc/free计数和已提交video帧进度诊断；覆盖本适配器视频/音频的自有frame header，不统计FFmpeg/GPU内部headers。独立native测试逐轮取消、join、close，检查100轮自有frames回到baseline及最终FD delta=0。另用ASan/UBSan、detect_leaks=1且无suppressions运行同样100轮scheduled-opacity取消。共享的FFmpeg/x264未重新instrument，不能说是GPU/所有第三方内部frame lease全资格；I-022仍partial。

## 验收入口与未完成

精确冻结源码/library/测试命令/早期失败见 implementation/evidence/opacity-keyframes/summary.json。真实UI set/preview/undo/save/fork/export、SDK归档/重开/实际采纳、split两侧编码输入像素、独立时钟/旧库/迁移/事务回归分别记录，不能拿旧200借作新SHA全过。

当前undo沿既有last-commit inverse合同，本批验证一次keyframe命令原子恢复；没有实现完整多级undo/redo栈或gesture coalescing。I-008还缺完整注册变换/关键帧其他参数/转场handles等；I-022还缺GPU/全FrameLease/V-003完整矩阵及其他硬依赖。真实resume underrun仍未解；schema9不能阻止旧writer共写；非Linux/物理多设备无新资格，RTC网络策略无变化不重跑、不绕过。
