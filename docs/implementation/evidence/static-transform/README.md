# increment1.16 — 静态transform2d真实CPU消费者

本目录summary.json绑定所在提交的生产+测试源码SHA256和native library/binary哈希；final-*为该冻结源码重新实跑，不借用上批209。commands.json记录实际cwd/env/argv/exit；toolchain-reused.json是同一已安装工具链前批读取的版本信息，本轮没有安装依赖，native/ASan重新构建，SQLite严格门禁及实际用例重新跑。

## 复跑入口

沿主维护者README已批准Flutter3.50.1/Dart3.14、SQLite3.54.1及Debian FFmpeg/Pulse：

```sh
export PATH=/workspace/toolchains/flutter/bin:$PATH
export LD_LIBRARY_PATH=/workspace/toolchains/sqlite-3.54.1
export STUDIO_MEDIA_LIBRARY=/workspace/agent-media-native-peer/libstudio_media.so
export STUDIO_TEST_VIDEO=$PWD/artifacts/local-video/input.mp4
export CHROME_EXECUTABLE=/workspace/toolchains/browser/chrome-test
cmake -S native/studio_media -B /workspace/agent-media-native-peer -G Ninja
cmake --build /workspace/agent-media-native-peer
```

执行commands.json各命令；private Pulse保持串行，不能将服务clock测试并发后把underrun删掉。STUDIO_TEST_VIDEO为前面本地资格生成的320x180/3秒BT709 limited CFR fixture，不上传用户素材。新SDK测试另在自己的临时目录生成128x72白色视频并显式setparams色标，结束仅删除自己的fixture。

Sanitizer构建沿ADR0022固定命令：Debug、`-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1`，exe/shared linker也加`-fsanitize=address,undefined`，目录/workspace/agent-media-native-asan-opacity。分别对普通及ASan ABI程序执行`opacity_cancel`和`transform_cancel`，ASAN_OPTIONS=detect_leaks=1:halt_on_error=1；四次各100真实活动取消，计数与exit见summary，绝不当作400个Dart测试。

run_selected.py存档实际云端驱动。复用时把commands.json复制到artifacts/local-video/transform-final-runs.json，summary.json复制到artifacts/local-video/transform-source-freeze.json，再执行脚本；改工具链/目录/源码须另冻资格，不复用旧binary hash。

## 保留失败

first-analyzer/test-analyzer：初稿revision类型/style/无效cast，已修。first-tests：白图只有部分容器色标，被COLOR_POLICY_REQUIRED拒绝，补真实frame setparams，不放宽门禁。first-matrix-analyzer：UI一处style。first-transform-100cancel和first-asan-transform-100cancel：新增mode分派未匹配，unknown test，不是取消成功；修真实分派、重新构建两个ABI executable再测。

普通/消毒器只涵盖本适配器自有AVFrame和allocator可检验范围，不能冒称第三方/GPU内部全部FrameLease资格。原真实resume underrun仍未解，旧writer共写未解决；未重建发布App/物理声卡/物理AV同步/稳定fps/非Linux/多物理设备/完整GPU或60秒VFR/HDR变换矩阵。Chrome5例只验资源/Inspector，不是Web原生效果或RTC互联。
