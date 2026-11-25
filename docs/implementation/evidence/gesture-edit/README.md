# Gesture / one-command evidence

本目录对应包含本目录的普通本地提交，**未push**。`summary.json`冻结26份生产/测试/package文件与native库hash；原e23a559/c8c12d8/c948c56保留，不构造不存在的GitHub提交URL。

## 重放

先按implementation主README配置批准工具链和native adapter；现有云端环境无需安装或重搭。原命令环境：

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1
export STUDIO_MEDIA_LIBRARY=/workspace/agent-media-native-peer/libstudio_media.so
export STUDIO_TEST_VIDEO=$PWD/artifacts/local-video/input.mp4
export CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test
```

本批真实执行的cwd/argv/额外环境/退出码/耗时逐项在`commands.json`。按顺序串行运行各group，不和Pulse/UI资格抢资源；native组内部明确--concurrency=2。UI必须在**packages/studio_editor_ui**运行，否则根workspace测试可能不构建material_ui声明的shader资产。`run_selected.py`是实际编排存档；重放需复制commands.json至其指定artifacts/gesture-edit目录并按自己的固定目录调整脚本及日志输出路径，勿覆盖自己的原资料。

如新机器没有原合成fixture，可在独立测试目录用与run_local_video.py相同的lavfi输入生成：`testsrc2=size=320x180:rate=30:duration=3`，`-vf setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=limited -c:v libx264 -pix_fmt yuv420p -an`，选择新输出路径，勿覆盖真实媒体；STUDIO_TEST_VIDEO指向它。测试仅在自建临时目录操作、删除fixture，不清理用户工程。

## 范围

八种SDK目标不等于八种timeline拖动UI；本批真实pointer UI是static opacity。UI实际40次MOVE/原生ghost图/一次undo-redo、无变化tap、Escape/pointer cancel/先hold再scroll-arena取消、SQL失败显示后显式Cancel；SDK实际独立进程staged100次后SIGKILL重开和完整rich AV/caption/proxy/coalesced color/archive fork/MP4。

最终计数只来自最后26文件冻结后的final-*所选group。所有first/second/third/fourth/fifth/sixth/*-before-fix及style等日志为**冻结前辅助/失败证据**，不能混入最终通过数。原SQL错误Text在滚动区外导致真实UI断言失败，添加控件旁错误后保留原断言；另保留一次patch cwd错误导致的重复失败。首轮247成功没有覆盖后来主动发现的public preview异步capability顺序回归：新反例真实失败，修正后重新冻结重跑，不借首轮成功。

另CTest、实际旧库/SQL/SIGKILL、真实monitor/故障probe与视频取消单列，不灌进Dart/App case计数。Chrome仅资源/Inspector，不是WebRTC或物理多设备资格。全部I-005/其余87/GPU/物理声音或AV同步/其他平台/巨量历史/所有安全Harness suite未闭合；旧underrun两失败仍未证解。详情见summary.notRun与ADR0028。
