# t76 工作分解验证（2026-11-24 Asia/Shanghai）

## 结果
- 原地发布第16/16A/16B；26验证卡＋61实现卡，全部unvalidated/planned；没有任务本身开始执行。
- 48项新增规划数据/条件依赖合成检查通过：24完整性＋24执行规划合同。目标阈值字段检查只是规划lint，不是模型质量/端侧性能验证。
- 146硬依赖、56子能力门禁、31平台/付费条件边；合并及14组平台×付费变体无环。所有V有实现消费者。
- 72个当前功能章节映射到具体任务；2个历史研究/逐项迁移章节只留证据，不造生产任务。
- 每任务有范围/不含、步骤/交付、实际未来验收入口/阈值/失败分支、资源费用、拟议实现文件与验收适配器、估计和并行规则。所有路径未核对真实工程，入口目前未实现。
- 强保全：只移除本轮标记块和明确TOC/import/UI state增量，源模块与本轮开始时逐字节相同，所有既有Schema和主规格无删改。

## 旧回归的准确口径
- 12套旧算法/Schema/spec测试＋旧文档逐项迁移＝13组，在已公开t68/t69精确迁移compatible口径通过；本轮无新增旧章节迁移。
- raw保留原4组旧整段基线比较失败：lifecycle-published-compat、vertical-published、ondevice-published、reconciliation，不声称它们原断言全过。
- t73旧发布检查原样复制后针对最新readback跑：21/22通过；唯一整模块比较因本轮获授权新增WBS/UI/import失败。保留prior-t73-audit/raw-results.log。t76自己的精确增量剥离保全检查通过，不修改原断言来伪装全绿。
- 既有Harness 26发布Schema/SQL＋45算法/安全oracles通过，许可25＋12、设备18合成oracles通过。部分历史算法测试本来无Page输入，保持原样；接受readback的发布/兼容检查指向本轮最终source。

## 可复跑（在本目录）
[box-local audit path] test_work_breakdown.py
[box-local audit path] export_work_items.py
[box-local audit path] test_execution_contracts.py
[box-local audit path] run_regressions.py compatible
[box-local audit path] run_regressions.py raw

最后一项应看regression-raw.json的逐组状态，不以runner退出码伪称全绿。

## 没有做
未运行任何V/I开发任务；未构建App、调用OS或真实模型、测试GPU/设备/生产负载/支付/后端，未部署、下载SDK/权重、购买设备/注册/付费/外发，未访问Mac私有工程或素材。TaskAdmission里的measured/trusted是合成fixture，并非实测授权。尚待用户选择任务与Profile后逐卡执行。
