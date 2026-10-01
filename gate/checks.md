# 检查清单

## 默认队列检查

- Agent 接手时：`python3 tool/shell.py doctor`。
- 提交时：由安装的 Git 钩子调用 `check --staged`，无需用户手工维护。
- 队列工具开发时：`python3 -B -m unittest discover -s gate -p 'test_*.py' -v`。含队列、状态包与编号三组测试，约 3 分钟；测试真实 CLI、进程锁、Git 提交和中断恢复，写入临时项目；不在每次业务提交时全跑。

队列检查只证明机械规则与记录一致，不证明项目产物正确或批准来源已经独立认证。

## 隔离 Agent 使用验收

当入口说明、队列用法或恢复流程发生重要变化时，按 [隔离验收规约](subagent-e2e.md) 另做空白上下文的真实 Agent 使用测试。它不替代程序测试，也不自动随业务提交运行；结果需区分模板缺陷、执行环境阻断和未覆盖范围。

## 项目专属检查

有实际需求时为每项增加独立标题，写明检查对象、工作目录、前置条件、原样命令或操作、通过条件、限制与方法来源；接入了提交钩子的，写明钩子何时运行、怎么安装（接法见 [gate 契约](AGENTS.md)）。

### 架构图纸检查

- 检查对象：图纸区 [truth/architecture/](../truth/architecture/AGENTS.md) 的图源与渲染产物，以及承载设计文档（`tool/diagram/registry.json` 的 `settings.design_doc`）里的 C1、C2 图源、编号边表与容器指针表。
- 工作目录：仓库根。
- 前置条件：Node.js 22.6 以上；检查本身不需要渲染依赖。
- 命令：`node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts`；检查暂存区加 `--staged`；查看判据加 `--criteria`。
- 通过条件：退出码 0、无红。三项判据：(e) 图源与渲染产物一致、(w) 架构图文对齐、(x) 架构跨层对齐。退出码 1 为有红，2 为检查本身无法运行。
- 限制：只证明图与边表相符、锚点可解析、产物不过期，不证明设计正确；设计对错由《架构设计与制图规范》第 9 节评审清单把守。检查不证明 SVG 可读，改图后另行目检。
- 提交钩子：暂存改动触及 `truth/` 或 `tool/diagram/` 时自动对暂存内容运行，有红即拒绝提交。每个克隆在仓库根运行一次 `sh tool/diagram/install-hook.sh` 安装；说明见 [tool/diagram/AGENTS.md](../tool/diagram/AGENTS.md)。
- 方法来源：制图工具随附的三项检查，见 [tool/catalog.md](../tool/catalog.md)“制图工具”。

执行输出与失败记录归对应任务，本清单不保存“上次通过”的状态。
