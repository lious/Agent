# ADR0012 — 原始PTS派生帧代理与AudioSink确认时钟驱动预览（increment1.8）

状态：受限开发切片；不替换原104份规格、原87项验收或GPU/P0门禁。

## 决策与真实用户路径

Linux原生编辑器显式“Build timeline video preview proxies”生成本机派生RGBA128
图像序列，然后可启用timeline video。导入已许可视频、提取持久音频，点击Play/Pause/
Seek/Rebind：每次取样只用实际Pulse服务确认的48k presentedSample与epoch；16ms定时器
只请求绘制，不累加wall clock，不把submitted/ring写入数当作呈现时间。
单轨原件映射与导出segment recipe现在共用不可变TimelineVideoGraph。实际导出仍从
校验过的原件解码，不截图Flutter，也不编码低清代理。编辑revision变更、stop/restart、
seek/rebind、失效时钟和生命周期均隔离旧结果；重绑保持暂停，不自动恢复声音。

## 原始时间、格式与资源

* C++ libav顺序生成一次RGBA图像序列；保留原始time_base/startPts/逐帧PTS/duration，
  不通过改写原PTS伪装归一化。Dart有理数半开区间/二分表定位，再定长offset读取。
* 真实CFR、VFR、7秒非零起点代理，各20个乱序点与独立顺序解码器对比PTS及RGBA。
  这不等于VFR已获编辑/导出资格；原CFR/SDR/admitted profile门禁继续生效。
* 该序列是**临时preview-only RGBA代理**，不是已持久化的SchemaProxy，不写根Schema、
  originalBlobHash或归档。关闭清理；重开必须明确重建；缓存缺失明确报错，不暗中改源。
* 每个SDK采用代理总量≤64MiB；单个生成中staging≤64MiB，因此两者同时存在时磁盘
  最多128MiB（不含原件/CAS/音频/其他进程）。每生成≤2048帧；像素保留LRU为2MiB。
  解码前尺寸≤2048²；这些不是进程总RSS/全局磁盘上限，也不保证任意120秒视频可缓存。
* 帧文件0600/O_EXCL/O_NOFOLLOW；失败/取消移除部分输出；整blob与逐帧SHA256校验，
  损坏/截断/非法映射拒绝。单生成与单timeline-read背压；读者lease结束再删目录。
* 正常close/cancel清理有实际验证；进程崩溃遗留临时目录的受锁启动回收与持久CAS pins
  尚未实现。不可宣称全生命周期cache/Schema资源闭包完成。

## 时钟与图像所有权

只允许当前project hash、playbackGeneration、native epoch和确认sample匹配的结果。
restart另有SDK generation，防止新native handle重复epoch而接纳旧frame。落后超过960
samples的结果丢弃；这是20ms处理新鲜度检查，**不是物理AV同步/显示延迟测量**。
UI单个异步解码；超时/晚回调释放ui.Image；image替换/seek/编辑/销毁释放自己的引用，
Flutter引擎负责消费中的引用。显示delivered/committed/stale/source skipped/late commits
诊断，不隐藏源帧跳过，不把postFrame callback当显示器扫描确认。

## 显式未完成与兼容边界

仅admitted单视频轨、1x、黑不透明背景、unity pixel aspect、源/画布相同尺寸；不同尺寸、
非黑背景、retime和已有不支持效果明确拒绝。没有完整CPU/GPU合成器/纹理lease资格，
没有同revision预览/编码前SDR patch≤2/255或100次GPU取消无泄漏资格。
原I-021/I-022/V-003以及上游I-015/V-004/P0依赖不能因此标complete。
实际Linux应用/软件服务monitor不代表物理声卡、人耳、物理AV同步或macOS/Windows/
iOS/Android/Web媒体实现；WebRTC原有受管网络阻塞保持，未重试或绕过。

## 验证与失败保存

命令、原始源哈希、实际测试、初始失败与修正见
`docs/implementation/evidence/timeline-proxy/`。先前并行underrun/UI超时不被本批通过覆盖。
本批FakeAsync widget视频版pause超时保留；移至真实Linux IntegrationTest binding后
发现native测试driver重复输入焦点缓存问题，重置driver缓存并断言实际controller值，
保留第一次实际UI seek失败，然后复测实际移动像素、暂停/seek像素变化和rebind。
不使用mock AudioSink、假时钟或降低原验收来消除失败。

第一轮完整回归另发现lazy viewport外busy indicator不可见，已有source-preview测试的
真实codec完成尚未到达时pumpAndSettle超时；将实际busy条固定为always-built overlay，
并修复workspace已close后widget dispose重复取消已关闭preview adapter。同期音频-only
rebind/resume出现真实underrun（sample25266），保留失败整报告。新增worker-loop最大
调度间隙与服务端实际target/prebuffer诊断；不放大队列、删除断言或宣称调度故障已修复。


## FullyLive实测后的修正（本批第3轮延伸）

手动driver推进帧可掩盖真实引擎负载，改为`LiveTestWidgetsFlutterBindingFramePolicy.fullyLive`后，
首次完整回归实际失败（直到EOF才有有效帧），未计为成功。预览现在缓存已完整校验的不可变
snapshot/graph/source映射，逐帧仅用namespace/project/head的SQLite轻量coherency fence；
该查询**不代替首次Schema/完整性校验**。UI用独立ValueNotifier刷新player，不逐帧重建整个编辑表单。
播放是best-effort软件预览：采纳/回调新鲜度检查不限制已显示旧帧的停留时间；晚帧/跳帧可见，
旧图像可能保持到下次替换。不能据此声称稳定帧率、20ms显示延迟或60秒物理呈现同步。

实际Linux Flutter进程还暴露GNU C++异常unwinder与Flutter运行时的符号interposition导致
`SIGABRT`。换为受支持Skia renderer仍失败，故不归因于图形后端。对**自有合成测试子进程**
的strace/GDB定位到`__cxa_rethrow -> _Unwind_Resume_or_Rethrow -> Flutter的_Unwind_RaiseException`。
Linux native adapter现私有静态GNU C++/GCC runtime，并用版本脚本只导出`sm_*` C ABI；
不向Flutter暴露C++异常/RTTI/unwinder符号。真实Flutter引擎已加载时新增sync/async缺失素材
错误回归，断言返回受控异常，不能以CLI成功替代宿主ABI验收。没有提升core/kernel权限；
core limit请求遭系统拒绝后未提权。GDB/strace来自官方Debian包，仅诊断自有子进程。

异常隔离后，真实UI还发现同一corked stream普通Pause→Resume会进入可控underrun，而
此前许多资格是Pause→Seek→Resume，未覆盖该路径。增加tlength/prebuffer仍实际失败，
故**回退原有请求值和硬边界**（ring8192frames，服务max4096frames）。保留失败，不声称已证明
Pulse内部根因。现在确认paused/clockValid的Resume从该服务确认sample重建stream并推进epoch，
不复用旧队列/旧时间历史，不按wall time外推；duplicate active Resume不重建。记录重建时
status snapshot中的unconfirmed tail（不是物理DAC的准确未播帧数）；需要等待新stream确认时钟，
不承诺无缝/低延迟或物理队列完全无重播。真实软件服务故障/重复操作与fullyLive UI重跑见证据。

GNU runtime静态链接改变Linux产物依赖，发行前仍需按实际GCC Runtime Library Exception、
libstdc++/libgcc及现有FFmpeg/libx264构建逐项做SBOM/许可和平台打包资格。本批仅源码开发切片，
不宣称已完成生产再分发/许可证审查或非Linux ABI资格。
