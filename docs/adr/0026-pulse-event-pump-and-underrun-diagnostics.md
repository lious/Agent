# ADR0026 — Pulse readiness 调度修正与不足诊断，不宣称间歇根因已闭合

状态：Linux Pulse 软件服务子集；原 I-023 仍 partial，旧失败不消除。保留 e23a559 crop/color 及原104/87验收/硬依赖，不扩存储。

## 有证据的缺陷与未知

原 worker 每轮 `pa_mainloop_iterate(loop,0)` 后无条件 sleep2ms。这在 socket/deferred 工作已经 ready 时也人为推迟后续处理；官方 mainloop 的 prepare/poll/dispatch 可以在实际 I/O ready 时立即返回，而以同样2ms作**最长请求等待**。修正为 `prepare(2000us) → poll → dispatch`，移除无条件 sleep；全部仍由同一 worker 访问 Pulse 对象，控制/stop最多在下一轮处理，OS调度仍可能超时，不保证物理2ms延迟。没有把 wall clock 用作项目时钟。

这是可定位的调度缺陷，不是已证明为所有间歇 startup/resume underrun 的唯一原因。原 e23a559 的 raster_clock 在 presented2877/submitted5168/ring8192时首次play失败，旧00c2e5d opacity_clock也曾失败。本批只加诊断、尚未改调度时的一次两case和一次完整旧probe都通过，反而说明**通过一次不能消除旧失败**。因此新结果无论绿红都不得叫“underrun已修复”。完整系统/P0/长期负载仍未验。

新增只读诊断：协商的 serverMinRequestBytes、实际 underflow index（Pulse API返回的字节域，不是项目时钟）、当时 client 可写请求量（未知为-1）、eventSourcesDispatched 和 pumpPolicy。保留原 maxWorkerLoopGap/服务latency；这些不是物理呈现证明或新的调度权限。下次真实失败应据其分析，不能凭 ring 满就推断服务队列满/无饥饿，也不能由一次probe猜测根因。

## 未放松的合同

ring8192帧、server maxlength32768字节、target/prebuf/minreq请求值、每轮最多4×1024帧写入、PCM有限值验证均不变。没有 prebuf=0、扩大队列、忽略 underflow、自动假成功或静默重试。真实不足仍 interrupted/clockValid=false 并冻结服务最后确认sample；原显式rebind/恢复重建、迟到epoch、暂停/seek/取消、500ms clock-stale/连接和cork deadline、实际drain EOF仍沿原合同。AudioBus、精确PTS/采样和crop→transform→color→opacity→dissolve像素顺序均未改。

官方资料（本批实际读取）：
- https://freedesktop.org/software/pulseaudio/doxygen/mainloop_8h.html ：prepare timeout单位microseconds，poll ready/timeout 后dispatch；同一线程访问约束。
- https://www.freedesktop.org/software/pulseaudio/doxygen/structpa__buffer__attr.html ：maxlength/target/prebuf/minreq；prebuf0会让不足时继续静音，本批不采用。

## 实测边界与发布边界

复用真实私有Pulse monitor/fault probe：worker SIGSTOP造成实际服务饥饿必须 interrupted/冻结；sink suspend、server SIGSTOP、rebind/resume、EOF、FD及非有限PCM/远端服务列表拒绝沿原断言，新增核对真实调度策略和协商诊断。Dart/UI/像素/归档/SQLite/取消按新冻结源码另记，不混用旧233、225或单独通过。精确结果见 `docs/implementation/evidence/audio-event-pump/summary.json`。

不是物理DAC、人耳听感、稳定帧率、GPU、其他平台或全任务验收。原87和XD10仍分列，SQLite3.54.1门禁不动。远端拒绝本批仅三次授权只读GET：适用branch rules=[]、repo rulesets=[]、branch protected=false且仍00c2e5d。公开状态显示Git Operations operational，但不能据此确定该push错误根因或排除局部故障；没有经证实需用户改规则/授权/身份的动作。不重试push，本批只本地普通commit，保留原错误与未发布两批源码。
