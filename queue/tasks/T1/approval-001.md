> 历史批准基线，不是当前任务记录。

批准人：用户
依据：用户在讨论 truth 文档方案时选择启用制图工具，同意联网安装约 400 MB 渲染依赖与安装制图提交钩子，并指示按“接入队列、启用制图工具、撰写三份 truth 文档”的方案执行，在本地 main 提交、不推送

父任务：None
依赖：无

# 启用制图工具

## 来源与目的

用户在讨论 truth 文档撰写方案时决定：启用模板随附的制图工具 `tool/diagram/`，用文本图源维护架构图并由程序核对图文一致；同意联网安装渲染依赖（约 400 MB）；同意安装制图提交钩子，并要求按“接入队列 → 启用制图工具 → 撰写三份 truth 文档”的方案执行，在本地 main 提交、不推送。

目的：让随后撰写的 `truth/工程架构.md` 能以 mermaid 图源承载 C1、C2 架构图，渲染成 SVG，并在提交时机械核对图源、边表与产物一致。

## 范围

- 要交付：
  - 图纸区 `truth/architecture/`：由 `tool/diagram/zone/` 复制的区契约、《架构设计与制图规范》《治理细则》三份，链接与“模板”措辞按复制后的位置改写；《治理细则》第 7 节写入本仓现状。
  - 根契约第 2 节地图：新增图纸区一行；`tool/diagram/` 一行改为“已启用”。
  - `tool/catalog.md`：制图工具从“可选工具”移到“项目专用工具”，写明用途、位置、来源与版本、前置条件、副作用、授权、验证与钩子安装方法。
  - `gate/checks.md`：“项目专属检查”登记“架构图纸检查”一项。
  - `tool/diagram/registry.json`：`settings.design_doc` 设为 `truth/工程架构.md`（该文件由后续撰写任务创建；声明 C1、C2 图名的 `l2_diagrams` 留给撰写任务）。
  - 本机：在 `tool/diagram/` 运行 `npm ci` 安装渲染依赖；核对 `puppeteer-config.json` 的 Chrome 路径；运行 `sh tool/diagram/install-hook.sh` 接上提交钩子。
- 不包含：任何架构图的绘制与 truth 正文文档的撰写；修改制图工具源码或队列工具；推送远端。
- 允许修改的位置：`truth/architecture/`（新建）、`AGENTS.md` 第 2 节地图、`tool/catalog.md`、`gate/checks.md`、`tool/diagram/registry.json` 的 settings、`tool/diagram/puppeteer-config.json`（仅在 Chrome 路径不符时）；本机未入库的 `tool/diagram/node_modules/` 与 `.git/hooks/`。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 运行环境满足 | `node --version` | 版本不低于 22.6 |
| A2 | 图纸区三份规则在位、链接可解析 | 列出 `truth/architecture/`；逐条核对三份文件中的相对链接目标存在 | 三份文件在位；相对链接全部指向实存文件 |
| A3 | 地图、工具清单、检查清单已登记 | 阅读根契约第 2 节、`tool/catalog.md`、`gate/checks.md` 的相应条目 | 三处条目齐全，描述与实际一致 |
| A4 | 夹具与检查通过 | `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/render-diagrams-accept.mts` 与 `tool/diagram/check.mts` | 夹具无失败（层二未声明前允许 9 例 SKIP）；检查退出码 0 |
| A5 | 渲染依赖可用 | `npm ci` 后用一份临时图源跑一次渲染，结束后删除临时文件 | 渲染成功产出 SVG；工作区不留临时产物 |
| A6 | 提交钩子确实拦截 | 安装后暂存一处会让检查报红的临时改动并尝试提交，随后撤回该改动 | 提交被拒绝并给出制图检查提示；撤回后工作区无残留 |
| A7 | 队列检查通过 | `python3 tool/shell.py doctor`；提交时的队列检查 | doctor 为 protection: ready、protocol: 2；提交检查通过 |

验收安排：执行者逐项实跑并在回执中附原样命令、退出码与输出摘录，标“未独立验证”；用户审阅后决定是否通过。

## 执行计划

1. 核对 Node 版本与 Chrome 路径。
2. 复制 `tool/diagram/zone/` 三件到 `truth/architecture/`，改写模板措辞与链接；《治理细则》第 7 节写本仓现状。
3. 更新根契约地图、`tool/catalog.md`、`gate/checks.md`，设置 `registry.json` 的 `design_doc`。
4. 跑夹具与检查。
5. 在 `tool/diagram/` 运行 `npm ci`，用临时图源验证渲染，删除临时文件。
6. 运行 `install-hook.sh`，用临时红改动试提交确认拦截，撤回。
7. 写回执、交付，同批暂存账本、任务视图与本任务改动并提交。
