## 7B · 构建依赖、许可交付与发布门禁

```text
native/studio_media/ffmpeg/{io,demux,decoder,encoder,muxer,resampler,scale}_adapter.cpp
native/studio_media/{graph_compiler,source_session,frame_cache,clock,frame_lease}.cpp
native/platform/apple/{vt_frames,metal_presenter,coreaudio_sink}.mm
native/platform/android/{surface_bridge,surface_encoder,aaudio_sink}.cpp
native/platform/win/{d3d11_frames,mf_capabilities,wasapi_sink}.cpp
native/platform/linux/{vaapi_frames,egl_presenter,pipewire_sink}.cpp
build-support/ffmpeg/{common,apple,android,windows,linux}.profile.json
licenses/{sources,patches,configure,notices,relink-kit,sbom,patent-review}/
fixtures/media/{pts,vfr,seek,bframes,codec-fallback,surface-lifetime,mux-cancel}/
// 共同构建意图；非已经跑通的跨编译命令：
--disable-programs --disable-doc --disable-avdevice --disable-network --disable-protocols
--disable-autodetect --disable-gpl --disable-nonfree --disable-version3
--enable-avformat --enable-avcodec --enable-avutil --enable-swresample --enable-swscale
// 以显式decoder/demuxer/encoder/muxer/parser/bsf allowlist缩包；libavfilter默认关闭。
// 有需要再开受审filter profile，绝不enable-everything或直接下载第三方all-gpl包。
// Android profile必须核对--enable-mediacodec/--enable-jni及JavaVM初始化；NDK路径不等于无JNI构建依赖。
// SourceLock: version=9.1, ref=n9.1, sourceURL, signatureFingerprint, sha256,
// patches[], toolchain+SDK+arch+deploymentTarget, configureArgs[], libs+licenses[], buildId

```

| 发布项 | 确定的实施选择与放行证据 |
| --- | --- |
| 版本与ABI | 本轮官方download与n9.1源码一致：libavutil61.19.100、avcodec63.24.100、avformat63.16.100、swresample7.6.100、swscale10.5.100；可选avfilter12.8.100。集成锁官方9.1 tarball/签名/hash及补丁，不把滚动trunk当已验证锁版。导出自身稳定C ABI，启动检查各库runtime major/build fingerprint，不能混不同major的头/二进制或让宿主注入另一份FFmpeg。同进程只登记一个匹配buildId的FFmpeg集合，FFI打开受信bundled库而非任意全局符号；宿主已有冲突版本则初始化拒绝并给对齐要求，不靠“每实例一个engine”伪装消除了动态链接冲突。 |
| 构建矩阵 | Apple用Xcode clang按iOS arm64/device及simulator、macOS arm64/x64分别产库再组自有XCFramework；Android用锁定NDK LLVM/sysroot逐arm64-v8a、x86_64测试ABI产so；Windows MSVC/clang-cl＋MSYS2 configure/NASM明确CRT；Linux GCC/clang与libva/libdrm/EGL显式pkg-config。具体SDK/toolchain patch版本及source hash由首个可复现构建锁文件登记，不编造“已构建”值。 |
| 依赖控制 | 基础不启用libx264/libx265/libfdk_aac、外部模型/Whisper filter或未知GPL/nonfree库。软件AAC使用FFmpeg原生aac。额外H264软件编码候选为经审计libopenh264，但源BSD许可与Cisco二进制专利条件是不同合同，不能宣称随App静态打包即可免费覆盖商业专利。字体/模型权重许可仍单独登记；CPU/glyph/BigInt依赖如FreeType/HarfBuzz/Boost也进入SBOM。 |
| 链接/重链接 | Windows/Linux/macOS及Android优先与独立libav*.so/dylib/dll shared链接并交付对应源码/notice；把FFmpeg .a塞入一个JNI .so仍是静态链接，不能因最终扩展名叫so就宣称已满足动态链接路径。iOS静态方案需RelinkKit（本App可重链接对象、准确静态库、链接指令/工具链/必要脚本）和签名/商店条件法律审查；LGPL动态链接也不等于零义务。EULA保留许可要求的逆向调试权，逐语言一致，保留版权、修改和源码获取说明。重链接/分发许可未闭合按1C风险放行并保留未合规事实；平台实际审核/安全/支付/隐私门禁不能由此覆盖。 |
| 最小能力/安全 | profile列出MP4/MOV、受测音视频/图片及其parser/bsf，不因一个扩展名开放全部demuxer。decoder使用新进程/平台隔离条件按宿主能力，至少有严格大小/时间/队列预算、协议/嵌套IO拒绝、CVE更新与不可信畸形媒体fuzz计划。文件上传仍由独立权限Downloader处理，FFmpeg不获得通用网络权限。 |
| 发布验收 | 逐架构产物输出avcodec_configuration/各library_license、组件清单、源码/补丁/依赖hash和SBOM，检查无意外GPL/nonfree或自动探测依赖。FFmpegKit退休，不依赖旧预编译包。专利按地区/用途/编码器和分发分别评审；商业SDK只比较，不替代用户已定主架构。 |

FFmpeg合成合同测试在box [box-local audit path]，结果architecture-test-results.json；公开定向资料在public-references/，没有克隆仓库、读取Mac工程或用户素材。测试只验证设计oracle，不链接FFmpeg。构建/设备必须再测：精准seek含B帧/VFR/负PTS、双源转场、纹理import/fence/取消、音频路由、持续热/内存、同preset fallback、MP4端点/faststart和畸形输入。现阶段不能标任一平台“已支持”。
