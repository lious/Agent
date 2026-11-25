## 8P · 智能Mask与本地图像去物体：坐标、边缘和推断来源

| 交互/模型 | 可实现的数据合同 |
| --- | --- |
| 点/框/画笔 | 单击正点、切换负点、拖框、画笔增减；Prompt记录源upright坐标，不是屏幕坐标。像素中心取(x+0.5,y+0.5)。K=1/3候选轮廓可选，人工锁tile；撤销新增Mask版本，原图不变。 |
| MobileSAM ABI | RGB upright uint8→long-side resize1024，宽高各自round；mean=[123.675,116.28,103.53]、std=[58.395,57.12,57.375]；归一后右下pad1024。encoder f32[1,3,1024,1024]→embedding[1,256,64,64]；decoder point_coords[1,N,2]，labels正1/负0/框角2和3/pad -1；mask_input[1,1,256,256]＋has_mask_input→lowResLogits[1,K,256,256]/IoU估计。native names按实际Pack ABI校验。 |
| 后处理 | logits上采样padded域→去pad→逆resize/ROI/方向回源。objectProbability经显式threshold/feather/dilate生成removeRegion或alpha候选；置信值不是物理透明度。边缘参数按源像素，不随viewport缩放。 |
| 文本/自动主体 | “选红杯”需真实grounder；候选GroundingDINO SwinT-OGC(代码Apache-2.0、checkpoint另审)文本tokens＋RGB→query logits/归一cxcywh框→源框→SAM。未装时请用户点框，不能把LLM猜框当grounding。自动主体可用局部网格点＋stability/NMS提候选；最大/中心只建议，不做身份识别。 |
| BiRefNet | general输入RGB1024²、[0,1]按ImageNet mean/std→末层logits[1,1,1024,1024] sigmoid→源尺寸前景概率。细边可供抠图，不保证头发/玻璃真实matting；画笔修边、去色提案独立。抠图不等于移除后补背景。 |
| 色彩/alpha | Mask r8/r16/f16明示，不gamma/ICC转换；RGB预乘alpha单独处理。HDR可用显式tone-map分析副本求mask再应用HDR源；生成式补洞/SR仅支持已验SDR，未同意不能悄降HDR。 |

```text
viewportPoint -> inverse(viewportPanZoom * timelineTransform) -> uprightSourcePoint
rawToUpright contains EXIF/container rotation; source geometry pinned by hash
ROI=(rx,ry,rw,rh)
newW=round(rw*1024/max(rw,rh)); newH=round(rh*1024/max(rw,rh))
xModel=(xSource-rx)*newW/rw+padLeft
yModel=(ySource-ry)*newH/rh+padTop
// inverse分别rw/newW和rh/newH，不能除同一个未舍入scale。
// ROI(100,50,1000,500)，源点(600,300)->model(512,256)。
MaskRefinementCommand {id,maskId,expectedMaskVersion,sourceFrameHash,
 operation:addPoint|removePoint|box|brush|threshold|feather|dilate,
 promptArtifactHash,paramsHash,expectedManualRevision,lockedTileIds[]}
MaskService.refine(command): NewMaskVersion|MASK_SOURCE_CHANGED|MASK_LOCK_CONFLICT
MaskService.toRemoveRegion(maskRef,threshold,featherPx,dilatePx): MaskAsset
// 每种prompt恰有一个匹配payload；越界/空mask/过大膨胀报错，不silent clamp。

```

| 擦除链 | 前后处理、异常和撤销 |
| --- | --- |
| 模式 | “移除并补背景”与“仅变透明”分开；后者只扣alpha不调用inpaint。object=1显式转holes=1。初始膨胀3源像素覆盖边缘/阴影可调，属于产品策略非效果基准。 |
| ROI/LaMa | mask bbox＋初始64源像素上下文边；手机目标ROI边≤512（产品策略，非模型极限）；超大物体建议桌面全图或用户改区。RGB f32[1,3,H,W][0,1]＋mask[1,1,H,W] holes1；按Pack对称pad到8倍数→输出RGB→去pad/逆缩放。非mask区保原像素，羽化在线性合成域混合。 |
| 手机FFT | FFC含复数FFT，不能假设普通ONNX导出全支持。目标org.studio::Rfft2/Irfft2适配：NCHW实数→[N,2C,H,W/2+1]实虚交错、norm=ortho、逆变换显式原H/W；固定FFT ABI和实现版本；FFTW GPL等许可状态如实列出，商业许可缺口按1C风险放行，不隐瞒构建依赖。CPU custom op与EP边界拷贝/内存纳入校准；需impulse/sine/随机tensor与PyTorch golden及整图误差验收，未过报MODEL_ABI_UNVERIFIED。 |
| 小洞回退 | OpenCV4.x项目Apache-2.0、inpaint.cpp另保其Intel/BSD式notice；不能只抄根LICENSE。Telea/NS用于小划痕/简单背景，清楚标“经典修补”；AI缺失不能悄换算法还称智能。大遮挡/文字/复杂结构可能幻觉；不可见背景是推断，不是恢复事实。 |
| 结果 | ImageEraseCandidate保存source/mask/pack/params/ROI/color/provenance；输出新raster layer与补全区域证据，原件无损。预览前后/遮罩/推断区；用户接受现有图层命令一次事务，撤销移除新层/恢复旧引用，不删除原件。取消晚到仅隔离候选，不能写用户图层。 |
