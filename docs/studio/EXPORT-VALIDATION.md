# T-3 导出校验

- 最新已发布Page已读取，导出79个章节的可读Markdown及完整规格。
- 87个任务ID在Page数据、JSON、CSV完全一致；26 V / 61 I。
- 所有共有任务字段与最新Page逐项比较一致；Markdown包含全部87任务。
- V全部unvalidated，I全部planned，无实现或真机通过声明。
- 全量迁移矩阵另外导出，避免Page分页遗漏。
- Schema保留机器可读JSON与原Page构造源码；DDL/规范代码块保留在对应章节。
- 路径脱敏检查通过；仅选择规划文件，没有用户附件/现有仓库源码。
- 这些是导出一致性检查；不表示设计正确、授权已获得或App已实现。

## 首次导出时的 GitHub 阻塞（历史记录，现已解除）

gh auth status：You are not logged into any GitHub hosts. To log in, run: gh auth login

未clone、commit或push；仓库访问权限/visibility未验证。需用户在box完成gh登录，或父Agent提供原生GitHub连接流程。不得推断用户Mac的登录可供box使用。

## 本次入库更新

用户完成原生CLI授权后，已确认账号lious可访问PUBLIC仓库lious/Agent；通过用户指定的gh repo clone方式操作。仓库原有README.md保持不变，新增独立docs/studio目录。最新云端开发授权见本目录README；历史Page快照不伪改。提交前重新检查87项任务状态、数量、字段和全目录hash及秘密模式。本次未进行App或真机测试，也未启动功能实现。

入库仅规范化行末空白/文件末尾换行；源码备份另已做绝对本机路径脱敏，未修改历史规则语义。
