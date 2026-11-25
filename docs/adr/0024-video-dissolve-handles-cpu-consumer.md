# ADR0024 — 精确 handles 的双源 VIDEO dissolve，复用共享 CPU 像素节点

状态：Linux DEV 子集已实现；不是原 I-008/I-022/V-003 整项资格。
沿用原 `docs/studio/spec/s4.md`、s5 Transition、I-008/I-022 原验收，原104份不改。

## 时域与实际消费者

cut=b，窗口严格 **[b-p,b+q)**，x=(t-(b-p))/(p+q)。A 按相同项目时间继续采样 out 之后的 q 源 handles；B 在 in 之前采样 p handles。本子集只开放视频同轨相邻、enabled、线性1x、同源尺寸 SDR/Rec709 limited YUV420、交付帧网格、linear curve、missingHandlePolicy=reject。不足真实已验证 stream availableRange 的 handles 拒绝；不复制端帧、不自动 freeze，不把非线性映射改成1x。freeze/audioEqualPower/未知技术没有消费者，继续只读保全/明确拒执行。p或q单边可为0但总长必须>0；原语义校验保留窗口/相邻/冲突边界。

共享 Dart TimelineVideoGraph 同时提供两条精确 source-time sample 和分段 encoder recipe；窗口/clip边界分片，最大两条解码腿，不重设各流时间原点。preview/AudioSink确认sample时钟消费者与encoder均用同一个 C++ 节点：每条腿 decode/color→transform→clip-local opacity，再在线性光 `(1-x)A+xB`，只在最后转回SDR YUV420。不是混RGBA128代理、YUV或UI截图。预览在全尺寸合成完成后才降显示尺寸。两条腿可独立带静态transform和hold/linear opacity；handle区间的clip-local曲线按原端值hold，不随slip移动。x以精确Q计算后floor到Q16（误差<1/65536），两端消费相同值；独立线性光参考与实际编码前像素检验，而非拿有损MP4作bitwise标准。

## 编辑/不可变历史与安全恢复

SetDissolve/RemoveDissolve是现有revision/writer-fence SQLite事务命令，分配Transition及Sequence版本；重复参数no-op，锁和坏handles不发布。Slip仍须重验两个handles。带转场时Split/Trim/Move/Roll/Slide显式要求先移除转场；Delete仍不能发布缺端点的文档。这是保守拒绝，不偷偷改窗口/丢效果。移除可单次undo；现有last-commit inverse不是完整多级undo栈，恢复payload/版本后commit revision仍单调增加，不宣称原全量undo验收完成。

实际持久测试揭露旧fingerprinter把所有transitions拒绝。仅让上述已执行子集进入**现有**sequence依赖闭包，包含两条clip/source/effect定义和transition；沿用历史legacy kind `transitions`，不改SQL表/Schema9/无转场旧指纹/旧raw hash。Transition不是独立frozen source，自己记录窗口和clip端点ID，其渲染输入闭包由Sequence持有。不新建指纹注册协议。另实际归档fork失败揭露左右clip引用未重映射，补现有ImportMap的owned effect/transition IDs、effectIds和左右clip端点；原始blob hash/bytes不变。

## 资源感知采纳

显式ResourcePreservation采纳仍先核对全部真实hash/stream事实；除了单腿transform/opacity，启用的dissolve还必须在真实window sample执行两源共享native消费者。受64节点上限/epoch/active-root fence保护，所有资格在原子发布新fork之前。独立可解码并不代表可组合，实际不同尺寸源的两个缩图均可解码，但直接joint CPU调用拒绝；正式采纳在原graph尺寸门禁更早拒绝，不绕过前置，原选择/ImportMap/归档保持。代表点资格不等于逐帧/全GPU/任意后续编辑资格；普通归档保全和原始数据的可写语义仍与本端可执行资格区分。

## 资源、取消与能力边界

最多两Input解码器；FP32 linear RGB双buffer与临时RGBA由RAII管理，沿用尺寸≤2048和导出Level/120000帧、4个取样等上限，编译/公开opacity-range schedule在分配前检查同样120000限制。每32行epoch取消；保留旧std::exchange反双释放修复。不改变预算、pins、GC或用户素材，不运行真实资料清理。旧opacity/transform取消模式不替换，新双源+transform+curve模式实际提交encoder≥2帧后取消100轮，普通/ASan/UBSan分别验自有AVFrame及FD。

仍是黑底opaque CPU reference，FP32+RGB8 staging，不是原FP16/GPU/全alpha/任意色彩/任意尺寸/全registry或稳定帧率资格。音频走原独立AudioBus、现有cut/mix；VIDEO dissolve不隐式创建等功率音频转场。预览由真实软件音频服务确认sample驱动，但不是物理声画同步。实际证据见 `docs/implementation/evidence/dissolve/summary.json`；旧resume underrun/旧可执行writer共写/非Linux/物理跨设备/RTC受管策略限制保留。
