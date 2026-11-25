# Agent

自己尝试搭建一个端侧 Agent。

- [工程规格与 87 项原始任务](docs/studio/README.md)
- [真实本地视频闭环：启动、验收、范围与限制](docs/implementation/README.md)
- [全部 87 项真实进度（无整任务虚报完成）](docs/implementation/task-status.json)

技术路线：Flutter / Dart 共享领域与 Harness、SQLite 事务存储，已连接 C++20 / FFmpeg
软件路径：双宿主 Linux 导入→单轨剪辑→归档/恢复→重开→本地 MP4 导出。
仅限 silent CFR Rec709 开发切片；已有精确源缩略图seek/缓存，完整播放/音频/AAC/硬件端口/模型尚未完成。
Web可编辑元数据/字幕，持久身份与手动WebRTC面板已接入；当前受管Chrome无host ICE候选，
正向加密协作未验收通过，不使用云端/中继回退。各物理设备及非Linux平台仍未验证；不是完整视频编辑器。
