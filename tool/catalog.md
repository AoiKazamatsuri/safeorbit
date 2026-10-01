# 工具清单

## 本地任务队列（模板必备）

- 入口：[shell.py](shell.py)；旧 [task_queue.py](task_queue.py) 兼容入口执行相同检查。
- 规则与格式：[queue_model.py](queue_model.py)（旧协议重放）、[queue_v2.py](queue_v2.py)（五态与窗口）；状态包：[state_pack.py](state_pack.py)。
- 用法：[queue-usage.md](queue-usage.md)。
- 依赖：Python 3.10+、Git；无第三方包、网络或后台服务。
- 写入：初始化接入本机 Git 钩子；维护机器账、任务视图和本机恢复数据；取状态包时删除过期的状态包缓存（`.shell/local/state/` 下，只留最近 2 个过期版本）。不会自行修改对象产物、提交或推送。
- 验证：[队列回归](../gate/test_task_queue.py)、[状态包与窗口回归](../gate/test_state_queue.py)和[编号回归](../gate/test_task_numbering.py)。

## 可选工具（随模板提供，默认不启用）

随模板提供的可选工具，接入时由 Agent 逐项向用户说明并询问是否需要：需要的按其说明启用，启用后移到下文“项目专用工具”；不需要的可以整目录删去。本仓已无待选的可选工具：制图工具已于任务 T1 启用。

## 项目专用工具

确实需要时为每件工具增加独立标题，写明用途、位置与说明、来源与版本、前置条件、副作用、授权要求与验证方法；接了提交钩子的，写明钩子何时运行、怎么安装。不把本次执行结果写在此处。

### 制图工具

- 用途：把系统架构图（C1 系统语境图、C2 容器图，需要时加部署视图与 C3 组件图）的 mermaid 图源渲染成 SVG 与可移植 SVG，并做三项检查——图源与产物一致、设计说明里的边表与图一致、上下层图之间的锚点对齐。
- 位置与说明：[tool/diagram/](diagram/AGENTS.md)；图纸区 [truth/architecture/](../truth/architecture/AGENTS.md)；承载 C1、C2 图源的设计文档登记在 `tool/diagram/registry.json` 的 `settings.design_doc`（本仓定为 `truth/工程架构.md`，由任务 T2 随文档一并登记：一经登记，检查即要求该文档在位）。
- 来源与版本：随 devtemplate 2026-10-01 提供，源自 envshell 仓 `packs/diagram/`（提交 4a439c5），经独立运行适配；与上游的差异见 [《治理细则》](../truth/architecture/治理细则.md)第 8 节。渲染依赖钉版在 `tool/diagram/package.json` 与 `package-lock.json`。
- 前置条件：Node.js 22.6 以上（检查与夹具只需 Node）；渲染与导出另需在 `tool/diagram/` 运行 `npm ci` 安装依赖（约 400 MB，需联网）。依赖目录已在 `.gitignore` 排除。
- 浏览器：本机 Google Chrome 154 的无界面模式能输出正确结果，但退出时等待超时、退出码为 2，导出器会因此判为失败（T1 实测）。本仓改用渲染依赖 puppeteer 25.3.0 钉定的 chrome-headless-shell 150.0.7871.24：`tool/diagram/puppeteer-config.json` 写相对仓库根的路径 `tool/diagram/node_modules/.chrome-headless-shell/chrome-headless-shell-mac-arm64/chrome-headless-shell`，所以工具命令须在仓库根运行；该路径是一条本机链接，在仓库根运行 `ln -sfn ~/.cache/puppeteer/chrome-headless-shell/mac_arm-150.0.7871.24 tool/diagram/node_modules/.chrome-headless-shell` 建立。`npm ci` 会清空 `node_modules/`，之后须重建这条链接。本机 `~/.cache/puppeteer/` 没有该版本时，可在 `tool/diagram/` 运行 `npx puppeteer browsers install chrome-headless-shell` 下载（联网，须授权；T1 接入时本机已有缓存，此命令未实测）。
- 副作用：渲染与导出写入图纸区的 SVG 与两份清单；`npm ci` 写入本机 `tool/diagram/node_modules/`；钩子写入本机 `.git/hooks/`。不联网（安装依赖时除外）、不产生费用。
- 授权：安装依赖与接提交钩子都须用户明确同意（根契约第 3 条）；本仓由用户在任务 T1 中同意。
- 提交钩子：暂存改动触及 `truth/` 或 `tool/diagram/` 时，对暂存内容跑三项检查，有红即拒绝提交；找不到 Node 22.6 以上也拒绝。每个克隆在仓库根运行一次 `sh tool/diagram/install-hook.sh` 接线，拆下用 `--uninstall`。
- 验证：修改本工具后跑夹具 `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/render-diagrams-accept.mts`；画图、改图后跑 `tool/diagram/check.mts`，检查项登记在 [gate/checks.md](../gate/checks.md)“架构图纸检查”。
