# 工具清单

## 本地任务队列（模板必备）

- 入口：[shell.py](shell.py)；旧 [task_queue.py](task_queue.py) 兼容入口执行相同检查。
- 规则与格式：[queue_model.py](queue_model.py)（旧协议重放）、[queue_v2.py](queue_v2.py)（五态与窗口）；状态包：[state_pack.py](state_pack.py)。
- 用法：[queue-usage.md](queue-usage.md)。
- 依赖：Python 3.10+、Git；无第三方包、网络或后台服务。
- 写入：初始化接入本机 Git 钩子；维护机器账、任务视图和本机恢复数据；取状态包时删除过期的状态包缓存（`.shell/local/state/` 下，只留最近 2 个过期版本）。不会自行修改对象产物、提交或推送。
- 验证：[队列回归](../gate/test_task_queue.py)、[状态包与窗口回归](../gate/test_state_queue.py)和[编号回归](../gate/test_task_numbering.py)。

## 可选工具（随模板提供，默认不启用）

这些工具的源码随模板提供，但不装依赖、不接钩子、不建它们的文档区。接入时由 Agent 逐项向用户说明并询问是否需要：需要的按其说明启用，启用后移到下文“项目专用工具”；不需要的可以整目录删去。

### 制图工具

- 用途：把系统架构图（C1 系统语境图、C2 容器图、C3 组件图）的 mermaid 图源渲染成 SVG 与可移植 SVG，并做三项检查——图源与产物一致、设计说明里的边表与图一致、上下层图之间的锚点对齐；可接为提交钩子，改了图或说明而没对齐时拒绝提交。
- 何时需要：项目要在 truth/ 里长期维护经确认的架构图，并希望图与文字说明由机器核对一致。只写文字说明、或只放示意图的项目不需要。
- 位置与说明：[tool/diagram/](diagram/AGENTS.md)，启用与删除步骤都在那里。启用后多出图纸子区 `truth/architecture/`（区契约、制图规范、治理细则，模板在 `tool/diagram/zone/`），在根契约第 2 节地图加一行；项目差异只写在 `tool/diagram/registry.json` 的 settings 里。
- 前置条件：Node.js 22.6 以上（只做检查与跑夹具时只需 Node）；渲染与导出另需在 `tool/diagram/` 运行 `npm ci` 安装渲染依赖（约 400 MB，需联网）并配置本机 Chrome 路径。依赖目录已在 `.gitignore` 排除。
- 授权：安装依赖与接提交钩子都须用户明确同意（根契约第 3 条）。
- 验证：启用后运行工具自带的红绿夹具与检查；接了钩子的，按 [gate 契约](../gate/AGENTS.md)“接入项目自有的提交检查”试拦一次。
- 来源：envshell 仓 `packs/diagram/`（提交 4a439c5），经独立运行适配；与上游的差异见 `tool/diagram/zone/治理细则.md` 第 8 节。

## 项目专用工具

尚未登记。确实需要时为每件工具增加独立标题，写明用途、位置与说明、来源与版本、前置条件、副作用、授权要求与验证方法；接了提交钩子的，写明钩子何时运行、怎么安装。不把本次执行结果写在此处。
