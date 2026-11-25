# Agent

自己尝试搭建一个端侧 Agent。

- [工程规格与 87 项原始任务](docs/studio/README.md)
- [首批可运行实现：启动、验收、范围与限制](docs/implementation/README.md)
- [实际任务进度（全部首批整任务仍为 partial）](docs/implementation/task-status.json)

技术路线：Flutter / Dart 共享领域与 Harness、SQLite 事务存储，后续接 C++20 / FFmpeg
及各端硬件适配。当前提供双宿主 Linux 最小标题编辑与持久化切片，不是完整视频编辑器。
