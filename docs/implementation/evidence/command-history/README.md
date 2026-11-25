# Persistent command journal Undo / Redo evidence

本目录对应包含本目录的普通**本地**提交；精确20份生产/测试源码和native库hash在`summary.json`。没有新GitHub发布地址；e23a559、c8c12d8及本批均未push。

## 重跑

在仓库根目录设置现有批准工具链（不下载新工具）：

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1
export STUDIO_MEDIA_LIBRARY=/workspace/agent-media-native-peer/libstudio_media.so
export STUDIO_TEST_VIDEO=$PWD/artifacts/local-video/input.mp4
export CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test
```

`commands.json`逐项保存真实cwd、argv、env、exitCode、耗时和日志；按顺序串行运行，勿并行启动Pulse/UI媒体资格。本目录`run_selected.py`是运行编排存档（其工作目录为上述固定checkout；重放前依`commands.json`调整日志/报告输出路径）。项目测试入口与参数均为真实Dart/Flutter/native命令。`tools/acceptance/verify_command_history.py --help`给出独立fixture三次SIGKILL入口，`verify_definition_history.py`实际使用旧store/document源；只触碰各自临时fixture，不清理真实工程。

## 结果边界

最终239项=214 native/领域/SQLite/SDK +13 FFI widget UI +5 Chrome资源/Inspector +7私有Pulse，均通过；另CTest3、真实monitor/故障probe、实际旧库/SQL/kill和800轮视频取消分别记录，不混为App测试计数。Chrome不是Web协作通过，widget不是新release窗口/物理设备验收。

`first-*`、`third-*`、`probe-style-fix.log`及`review-script-edit-error.log`是**冻结前辅助/失败证据**，不能计入最终239。早期unknown-version fixture只改payload导致先触发hash防篡改，现已同时更新有效inputHash以真实验证未知版本拒绝；记录见REVIEW。当前7项Pulse通过不能消除e23a559 raster首次play presented2877和00c opacity_clock旧失败。

全I-005仍partial：1000 seeded标题history不是1000全NLE操作随机验收；O(n)cursor、保守tip/full-root逆操作不代表巨量历史UI性能/字段级协作/coalescing。未知历史资源必须通过现有可写准入；不默丢opaque。归档fork依原规格无源可执行undo历史。原87与XD10状态分别保留于相邻implementation状态文件，原104验收不改。
