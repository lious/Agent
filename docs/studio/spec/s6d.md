## 6D · 个人开发者分阶段真机验收：先借测，不先采购

| 阶段/代表 | 明确工作负载 | 采样与目标通过线 |
| --- | --- | --- |
| V0 · 不买机器 | 保持本轮合成DTO/Schema/门禁/预算/时间映射测试；冻结待验证Profile、公开fixture hash、工具chain和测试脚本版本；只用自拟/合法公开素材。 | 这些只能验证规划一致性，不能把source字符串、oracle或Schema测试当设备/模型效果。没有实测时保持planned。 |
| V1 · 两台手机优先 | 若能借到：iPhone13 A15与Pixel8a/8GB（或等价已有SKU并记录差异）；60秒1080p30 SDR、6个clip/3视频轨+2音轨+字幕，10分钟长工程；1080p30导出和720p代理；先不加载AI。 | 每配置冷启3次、稳态10次、连续负载20分钟；记录OS build/环境温度/电量/供电/温度状态/PSS或footprint/进程峰值/codec实际路径。目标：无崩溃/OOM、随机20个seek定位±1项目帧、导出A/V偏差≤20ms、无错误帧或时间漂移；不是已测结果。 |
| V2 · 小模型与图片 | 同两手机，Qwen1.7B Q4 ctx4096/输出1024、20条工具JSON fixture，Whisper base两分钟中英/静音/音乐；RNNoise；MobileSAM点框/负点、LaMa512 ROI、SR1024源图分块；各模型单跑后与预览竞争。 | 分别冷/热各3次，重复10轮与memory pressure；逐项测峰值、首token、tokens/s、RTF、mask/字幕人工QA。工具执行必须100% Schema+权限校验，不合格不执行；质量/耗时产品阈值由样本确定，不能先承诺实时。手机进阶未过则单功能待适配，不牵连基础编辑。 |
| V3 · 借一桌面＋一台M系列 | MacminiM1 16GB或已有Apple Silicon记录实际内存；已有Windows/Linux独立GPU桌面先12GB级测试SAM2小块/分离/克隆/ACE；YuE2/Wan5B只在能借到的24GB BF16合适GPU再测。 | 每模型独立环境/组合Profile；测启动、offload、VRAM/RAM峰值、GPU资源争用、取消后释放、3段不同运动与遮挡。没有24GB机器就保留未验证，不要求先买或默默租云；Linux与Windows模型支持不互相冒领。 |
| V4 · 补最少碎片样本 | 再借另一Android GPU厂商机型；若首台Mali/Tensor则补Adreno，或反之。iPadAir5借大屏/内存共池。Windows集显无CUDA测基础路径。Web Chrome/Edge及Safari/Firefox分别跑fixture。 | 只在完整签名组合通过后扩大机型列表。借不到的浏览器/机型保持实验；不能把模拟器跑通计作热/内存/硬编真机覆盖。 |
| 媒体交叉样本与故障 | 基础H264 Main8bit420 1080p30/AAC；H264 High422、HEVC Main10/PQ/HLG、4K60、VFR、旋转/非方形像素、无音频/多音轨、损坏包、alpha；前后台/锁屏/来电、权限撤销、磁盘满、拔盘、崩溃恢复。 | 每样本按import/decode/preview/encode/mux单独记录pass/fallback/blocked/unknown及fixture hash；验证显式HDR处理、输出PTS/时长/色彩、同一revision保存恢复/手改保护。目标为有解释地处理，不要求所有格式必成功。 |
| 发布资格而非速度宣传 | 同一Profile真实持续运行、热降频、内存/存储压力、后台checkpoint恢复；对长工程100次编辑/10次autosave、随机终止10次，检查durable revision/手改字幕与候选不覆盖。 | 目标：已durable编辑零丢失、无晚到候选自动覆盖、取消后不再提交新费用；移动交互延迟/预览drop率/导出速度记录分布后再定宣传值。OS不准后台执行要正确suspended而非假装完成；无有限时限保证的GPU任务不承诺立即取消。 |

首轮不确定清单：项目Flutter/engine/Dart与完整原生工具链未锁；各模型转换/量化hash和EP算子覆盖未锁；指定手机GPU/CPU的完整mask+LaMa、视频时序补全、克隆、SA Small离线ABI/峰值和质量未实测；Web demux/mux库版本未定；HDR跨端参考渲染/硬件profile、移动后台与外接文档provider持久化须构建后验。不会由NPU TOPS、桌面README或文件大小填补这些证据空白。候选硬件档与阈值会随记录到的工作负载修订，版本升级必须重新资格测试而非无限扩大承诺。

本轮证据与审计保存在box目录 [box-local audit path] ：逐行矩阵可从published-source抽出为JSON/CSV；REVIEW.md保留三轮实际修正；oracles.py/test_oracles.py验证准入语义，test_published.py验证发布后Schema/引用/矩阵完整性与旧正文保全，沿用明确历史迁移合同运行已有回归。它们不是App构建、OS API调用、模型效果或负载测试；正文只保留本节当前规则，不加入历史Review流水账。
