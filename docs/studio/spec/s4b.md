## 4B · 参考仿色、局部光效与传统风格：精确而不冒充生成

| 算子/参数 | 可编码算法、适用边界与门禁 |
| --- | --- |
| referenceColor@1 | 输入源/参考的已授权ROI与可选主体保护mask；先显式SDR/ICC转linear709，取log-luma的p10/p50/p90作受限单调分段映射，亮度倍率限制[0.5,2]；色彩取非饱和有效像素的通道均值差，线性差值限[-0.1,0.1]。y=(1-a*m)*src+a*m*matched，strength a∈[0,1]；m=1-protectCoverage。小样本/近黑/高光溢出/肤色缺证据返回REFERENCE_COLOR_UNSUITABLE，不能声称复刻任意电影LUT或物理重光照。分位数/epsilon/采样grid固定随operator版本，不由平台随意猜。 |
| localLight@1 | 椭圆或用户mask、center/axis以源归一坐标、radius>0、softness[0,1]、EV[-2,2]、tint线性RGB[0,1]、protectMaskRef、strength。在mask内做受限exposure与screen光层，确定性linear-premultiplied RGBA合成；不生成人体/新阴影几何，背景替换只是独立raster背景层，主体用已接受alpha。用户A/B、调强度/选区、修边或撤销。 |
| classicComic@1 | 明确标传统滤镜：已归一SDR RGB→固定参数双边平滑→亮度Sobel边缘→有限色阶量化→强度混合；radius整数1..16、edgeThreshold[0,1]、levels整数2..16、strength[0,1]。sketch为灰度/边缘专用preset，不称AI人物重绘。OpenCV若采用须锁版本与per-file许可，不引AnimeGANv2受限权重。 |
| 注册/持久化 | 以上为待实现受审vendor Effect（studio.image/referenceColor、localLight、classicComic），pluginVersion=1.0.0、owner=imageLayer；字段闭合并在Registry登记参数/动画白名单、资源walker与CPU/GPU同fixture。未注册或缺backend报UNSUPPORTED_IMAGE_OPERATOR，不能把type写成已有colorBasic偷执行。requiredFeatures声明新算子；旧App只读/阻导出，或用户明确烘焙副本。 |
| 顺序/取消/测试 | 先source色彩→可选参考/风格→Mask/transform→受控光层→文字；参数归一缓存含源/参考/保护mask/算子版本/hash。交互只发preview generation，晚帧丢弃；accept一次setEffect或新raster候选、Undo恢复旧参数/引用。测试strength0像素不变、保护mask1原样、透明边不变、极黑无NaN、ROI越界拒绝、CPU/GPU容差/字体不被风格化。 |
| 保留待决 | 高级色调曲线UI/局部复杂调色与完整HDR LUT仍二期/待锁算法，不因补传统算子而声称全套专业调色已完成。所有美学质量/肤色/halo均需真实样片与人工验收，不由公式自动保证。 |
