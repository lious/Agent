# ADR0025 — Crop / ColorBasic 的共享原件 CPU 消费者

状态：Linux DEV 的有界、静态、黑底 SDR 子集；不是原 I-008/I-022/V-003 整项完成。原104份、原验收及硬依赖不改。依据原 s4 与 s5 既有 CropParams/ColorBasic；未增加 Schema、表或指纹注册协议。

## 坐标、顺序与精确时间

只开放 `crop → transform2d → colorBasic → opacity → VIDEO dissolve`。Crop 的 left/top/right/bottom 是**源归一化像素边界**，严格 0≤left<right≤1、0≤top<bottom≤1，不是目标画布裁切或自动缩放。原文要求 coverage 乘 RGB/alpha，但未固定亚像素边界的栅格算法；本 CPU v1 明确采用源矩形 `[left*W,right*W) × [top*H,bottom*H)` 与每个源 texel 方形的相交面积作 coverage，再沿 ADR0023 逆矩阵/像素中心做 premultiplied linear 双线性取样。Crop 不改变画布/anchor 的全源 extent。这个确定性 CPU 选择不等于 GPU 已匹配。

ColorBasic 在 transform 后，coverage>0 的内容先 unpremultiply，在线性709 RGB 按 **×2^exposureStops → 围绕 .18 contrast → 基于 .2126/.7152/.0722 luma 的 saturation**，再乘回 coverage 和 clip opacity。exposureStops∈[-8,8]、contrast/saturation∈[0,2]。完全透明处保持0，不能因 contrast 为0而点亮被裁掉区域。中间负值/超1值保留到 opacity/两源叠化之后才执行一次最终 SDR transfer/clamp；不能 exposure 先 clip 再 contrast，或给每个 dissolve leg 先 clip。这不是给黑底 RGB 做显示空间滤镜。

共享 Dart TimelineVideoGraph 将每条腿的静态 raster 参数与准确 sourceTime、clip-local opacity schedule 一起传给同一个 native 预览/编码节点；AudioSink 服务确认 sample 的 timeline 选择也消费同一参数。两个 dissolve leg 可独立裁切/调色；原窗口/handles/源时间规则不变。非 identity raster 必须回真实原件，不对临时 RGBA/proxy 直接滤镜。预览全尺寸处理后才缩图；编码证据捕获真实 `avcodec_send_frame` 前的帧，不拿 UI 截图或有损 MP4 作为逐字节标准。

## 编辑、拒绝与缓存

SDK/UI 真正设置完整 crop 四边、exposureStops/contrast/saturation，持久 effect/clip/sequence 版本、no-op、锁、revision/writer-fence 与单次 inverse 沿原事务。添加节点只对**已通过准入**的本端已知列表按 canonical 顺序插入；导入的逆序/未知/pluginVersion/extension/动画 crop 或 colorBasic 不会被重排/删除来换取可写。未支持的 font/mask/imageDocument/library/LUT/retained 仍保全只读、拒绝执行，不能把 hash 闭包一致说成渲染等价。

命令/公开 preview 在首个 await 前深度验证并捕获不可变参数；preview cache 及资源感知采纳的 qualifiedNodes key 含两类 raster。启用的节点在发布采纳 fork 前仍做真实 bounded native 资格，不只检查 `staticRasterV1` capability。归档/fork 复用已有 typed ImportMap、effect owner 映射和原始 blob，不新增存储旁支。Split 克隆 owner/effect ID；静态 crop/color 不随 trim/slip 重写参数，source time 和 opacity 曲线沿原规则。单次 undo 恢复 payload/versions，提交 revision 单调；不是多级 undo/redo/coalescing。

## 有界资源、真实验证与限制

最多两 Input，沿用尺寸、120000帧/4编码取样/64资格节点/内存和预算门禁；每32行及最终转换取消检查，原 std::exchange 解码所有权修复不动。新路径增加的只是现有 RGBA input copy 和标量参数，不新开线程、不隐式云传/中继，不改 pins/GC/删除策略。四种100轮 active-cancel（至少2帧已提交）普通与ASan/UBSan分别记录，自有AVFrame/FD与第三方/GPU内部资源的资格必须区分。

真实测试包括：64.5像素边界半 coverage、contrast 不能照亮裁切外、exposure/contrast/opacity 和超1 leg dissolve 的独立数学参考、真实红源饱和度/有符号中间值参考（≤2/255）、两腿 crop/color+transform+opacity curve 的四个编码前像素、有效未知动画只读保全、native 恶意 recipe 创建输出前拒绝、SQL 后段 abort、真实 UI/归档 fork/关闭重开/资源采纳。准确结果和未运行项以 `docs/implementation/evidence/raster-effects/summary.json` 为准。

仍是 opaque SDR709 limited YUV420、同尺寸单轨/1x、黑底 CPU FP32/RGB8 staging，不是原 FP16/GPU/全 alpha/全 registry/任意色彩/任意分辨率。没有静默增加 animated crop/color、luma 或 LUT 消费者。Pulse 软件服务时钟测试不能证明人耳听到/物理同步/稳定帧率；旧 resume underrun 和 00c2e5d 的224过1失败必须保留，即使当前某次通过也不是修复。Schema9不能阻止旧可执行writer共写。非Linux、物理跨端及RTC受管策略限制不变，不重试绕过。
