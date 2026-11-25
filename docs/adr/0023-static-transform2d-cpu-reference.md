# ADR0023 — transform2d@1真实CPU消费者（increment1.16）

## 原合同与边界

逐条依据原s4 transform2d/crop-mask-opacity/固定RenderGraph顺序、s7a preview-export共图，延续I-008/I-022/V-003，不改104快照或87项验收/硬依赖。新增已实现的 **静态** transform2d@1.0.0，不是另一个filter字符串时间线或仅schema声明。原未知effects/resources和未实现transform动画继续保全只读/明确拒执行，不能清空曲线降级。

## 坐标、采样、色彩与alpha

Schema参数完整七个：translateX/Y为画布像素；scaleX/Y独立正数≤100；rotationDeg；anchorX/Y源归一坐标[0,1]。M=T(position)·T(anchorPx)·R·S·T(-anchorPx)，anchorPx=(anchorX*源width,anchorY*源height)。画布Y向下，正角度顺时针。对每个输出像素中心(x+.5,y+.5)逆变换，减.5后按四邻域双线性取样；越界邻居coverage=0，不夹到边缘、不改源availableRange、不重复应用旋转metadata。

同尺寸opaque Rec709 limited YUV420源→显式BT709 full-range RGB8→FP32 linear lookup；双线性在linear、premultiplied颜色空间进行，透明越界邻居为0；之后应用同一clip-local opacity曲线、合成到已准入不透明黑背景，再transfer/RGB8→YUV420交encoder。数学上覆盖乘色与黑背景合成一致，但**不提供可传递alpha平面、多轨透明合成或alpha源支持**，MP4 alpha恒255。与原P1 FP16/GPU仍有明确资格差异，不能称完整I-022。

预览在原件全尺寸上执行同一个native函数，最后才display下采样；不对RGBA128代理做变换，也不截UI。项目帧时间→source映射与现有opacity关键帧求值完全复用。native逐segment预校验/编译一次transform，渲染逐像素逆映射；opacity和transform固定顺序，不能接受未知或反向effect顺序而默换语义。identity是实际bypass，避免额外色彩roundtrip。

## 有界执行/兼容

本CPU执行profile沿现有≤2048×2048 YUV420 effect限制和H264 level/总120000帧门禁；新translate/rotation绝对值≤1e6，scale≥1e-6以约束逆矩阵。它们是显式更窄的CPU资格，不修改持久Schema；超出返回TRANSFORM_CPU_PROFILE_RANGE，不clamp，项目保全只读。奇异/非finite/缺或多字段/非法anchor/scale/动画/版本/扩展都拒绝；native在创建输出前再校验。越界坐标在转int前排除，避免逆矩阵越界转换。

RGBA8输入/输出各一幅，最大两幅32MiB（不含已有codec/SWS/decoder资源）；不创建随时长扩张的图像序列。每32行epoch检查继续取消；现有总帧预算与256-key曲线预算不放松。既有double-free std::exchange修复保留，新增transform+curve活动取消，同原opacity取消分别普通/ASan/UBSan各100轮。

SDK/NativeMedia的staticTransform2dV1 capability明确门禁；旧adapter不支持则拒执行，不仅凭JSON合法就运行。UI提供X/Y、uniform scale、rotation四个显式输入，本按钮设置source-center anchor，完整非等比/anchor参数通过同一SDK操作可用；非静态transform不自动删除。所有修改走原命令/revision/不可变版本，split克隆effect owner，trim/slip不改变静态变换，既有opacity曲线裁切/重基准不改变。

## 实证与未完成

冻结源/完整命令、实际白色图形的半像素linear coverage、缩放/90°旋转/anchor/平移、identity、preview与真实encoder-input、保存归档fork/reopen/split、真实UI和私有音频服务clock测试见implementation/evidence/static-transform/summary.json。初次生成white fixture缺transfer/primaries，被原COLOR_POLICY_REQUIRED正确拒绝；用已有golden同样的显式setparams生成fixture，未放松生产门禁。早期分析错误/失败均保留。

这不是完整EffectRegistry、转场handles/luma、GPU/FP16、P0/60秒VFR/HDR、稳定播放fps/物理声画同步或跨设备资格。全多级undo/gesture、resume underrun、旧writer共写限制保持；RTC策略无新条件不复跑、不绕过。原87和XD10分开统计，整项未凭此partial闭合。
