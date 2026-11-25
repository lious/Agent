# increment1.15冻结证据：opacity关键帧/真实取消

`summary.json`记录本批最终生产+测试文件hash与native两个library/binary hash。它所在commit就是这些源码的冻结commit；最终运行之后只改docs/evidence。`commands.json`按真实顺序记录cwd、完整argv、env和exit code。不是全仓或全部87任务通过声明，也不重用此前182/200计数。

## 复跑

沿维护者README现有官方Flutter/批准SQLite/系统FFmpeg和Pulse工具链，先在当前源码构建native：

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1
export STUDIO_MEDIA_LIBRARY=/workspace/agent-media-native-peer/libstudio_media.so
export STUDIO_TEST_VIDEO=$PWD/artifacts/local-video/input.mp4
export CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test
cmake -S native/studio_media -B /workspace/agent-media-native-peer -G Ninja
cmake --build /workspace/agent-media-native-peer
```

使用已存在或按前一批local-video资格生成的320x180三秒BT709 limited CFR fixture（不要上传用户素材）。对照commands.json分别执行命令，Pulse必须用已有private service wrapper，不能让4个时钟用例并发抢服务。Chrome只验资源闭包/Inspector，绝不是RTC正向或物理多设备。

独立sanitizer：

```sh
cmake -S native/studio_media -B /workspace/agent-media-native-asan-opacity -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  '-DCMAKE_CXX_FLAGS=-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1' \
  '-DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address,undefined' \
  '-DCMAKE_SHARED_LINKER_FLAGS=-fsanitize=address,undefined'
cmake --build /workspace/agent-media-native-asan-opacity
ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 \
  /workspace/agent-media-native-asan-opacity/studio_media_abi_test opacity_cancel
```

`run_selected.py`是本云端目录下实际使用的串行命令驱动存档。若复用它，将commands.json复制到artifacts/local-video/keyframe-final-runs.json，将summary.json复制到artifacts/local-video/keyframe-source-freeze.json；修改root/toolchain路径应明确另记资格，不借用原binary hash。独立命令不依赖此脚本。

## 失败与覆盖边界

- first-100cancel：真实heap corruption，定位并修复throwing decode前frame所有权未转移的double-free；不是环境跳过。
- first-matrix-native：保留了精确sample被帧量化破坏的旧断言，生产代码恢复exact sample、新增显式sampleFrame，原精确断言未降低。
- clock-black-assertion-failure：初稿把YUV420→RGB8后nominal black误写理想RGB0；既有static golden明确0..1。改与独立显式opacity0输出全字节相等，alpha255，沿用原容差不是放宽原验收。
- new-tests：初稿误把last-commit inverse当多级undo；改测一次命令undo，仍公开多级栈缺口。
- total-budget-review/fixed：初稿外来JSON先违反duration一致性，后被既有import duration门禁拒绝；未绕过门禁，改用真正MoveClip生成长项目，SDK在任何curve schedule分配前按同一native120000总帧上限拒导出且无产物。
- first/second/third-freeze与runs用于区分中间源码；只有summary和final-*代表最终冻结覆盖。100取消计数只涵盖应用自有AVFrame header，ASan/UBSan没instrument共享FFmpeg/GPU内部，不能宣传完整GPU/frame-lease达标。

未解resume underrun、旧writer共写、完整GPU/V-003/转场/变换、物理AV/稳定帧率、多级undo/gesture、其他平台与真实多设备限制仍保留。完整状态分别见../../task-status.json、../../multidevice-status.json；104原快照和原验收/硬依赖未改。
