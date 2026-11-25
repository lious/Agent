# ADR 0002 — 真实、本地、受限视频竖切（2026-11-25，Asia/Shanghai）

状态：开发切片决策，不替换原 87 项验收，也不是平台发布批准。

## 实际连接的实现

Flutter 双宿主 → 共享 Dart SDK → 精确有理时间/单视频轨编辑代数 → SQLite v2
事务/CAS/fence/receipt/版本历史/原件引用边 → namespace CAS 原件 → C++20 FFmpeg
libavformat/libavcodec/libswscale → 冻结 revision 的软件 H264/MP4 → 完整重探测 →
同目录 fsync/rename/fsync 发布。生产路径没有调用 ffmpeg 命令行；CLI 只造测试素材。

工程归档是真实 ZIP，包含 canonical snapshot、manifest、穷举 checksums、CAS 原件。
验证中央目录/大小/路径/重复项后才解压至内存；不按 ZIP 路径解包到文件系统。
恢复先完整校验再导入原件，fork 重映射所有本切片所有权/引用 ID、namespace、revision；
不携带 session、secret、审批或后台执行权。活动工程 ID 保存在 SQLite，重开恢复选择。

## 显式边界 / 与全部验收的差距

- 支持单视频轨、1×、CFR、Rec709 limited 8bit、像素宽高比 1、黑色背景、偶数边长
  ≤2048、≤120fps、≤120000 帧。没有音频输出、缩放、GPU、预览、代理或随机 seek。
  含音轨输入必须明确确认 video-only；未知色彩/VFR/旋转/alpha 不静默当已支持。
  stream 起点/时长未知或首解码帧 PTS 不匹配起点时明确拒绝，不以零点/全容器时长冒充流事实。
- 编辑支持 append/split/move/lift/ripple delete/trim/roll/slip/slide；有轨锁和字段锁。
  尚无多轨/编组/link/snap/复制粘贴/compound/关键帧/字幕。复杂合法工程拒绝写入，
  不降级重写。normal trim/lift 保留尾 Gap；ripple 才缩短总长。
- undo 恢复完整旧定义 pin，但 project revision 增长；再编辑从历史最大版本 +1 分配。
  这不是完整 undo/redo 栈、readset 或租约续期系统。
- 显式归档保存冻结快照；UI 区分当前与本会话已归档 revision。没有 autosave scheduler、
  合并并发 save、journal tail 恢复扫描、增量备份或 GC；不得把 SQLite 日志称为全部 I-011。
- CAS 导入最多 1GiB，归档输入最多 128MiB、展开总量 256MiB、10000 项；内存打包，
  不是大素材流式归档。原件先完成发布，再提交 metadata；失败可留未引用 CAS，不做删除。
- 同目录发布只在 Linux 应用独占目录验证。没有恶意同 UID 进程的 TOCTOU 防护或完整
  AVIO FileToken/FD sandbox；C ABI 是受信宿主内部接口，不能直接暴露给模型工具。
  已拒绝网络 protocol 和外部 MOV data references，但不声称完成全部越权路径测试。
- 输出拒绝当前 managed CAS、SQLite 和本会话选择过的原件路径。原件外部路径不进 Project
  JSON，也未持久化 host FileRegistry；跨会话防误覆盖/完整授权文件系统仍需实现。
- FFmpeg 来自开发机系统包，capabilities 记录真实版本、配置及 encoder。系统配置含 GPL
  libx264；未冻结自建源码/SBOM、未批准二进制再分发。许可事实 unknown 是 warning，
  不是伪造授权；隐私、预算、同意、鉴权、完整性门禁没有因此放宽。
- Apple/Android/Windows/Web、Ubuntu24.04 指定硬件管线、AAC/音画同步、真机、驱动、
  模型、云 API/支付/部署均未验证或未实现。Linux 云开发机不是用户已选定的发布 P0。

原 104 份规格快照保持不变；逐项差距记录在 docs/implementation/task-status.json。
