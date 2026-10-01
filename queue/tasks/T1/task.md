# 启用制图工具

```json
{
  "id": "T1",
  "revision": 5,
  "assignee": "Claude Code",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户在讨论 truth 文档撰写方案时决定：启用模板随附的制图工具 `tool/diagram/`，用文本图源维护架构图并由程序核对图文一致；同意联网安装渲染依赖（约 400 MB）；同意安装制图提交钩子，并要求按“接入队列 → 启用制图工具 → 撰写三份 truth 文档”的方案执行，在本地 main 提交、不推送。

目的：让随后撰写的 `truth/工程架构.md` 能以 mermaid 图源承载 C1、C2 架构图，渲染成 SVG，并在提交时机械核对图源、边表与产物一致。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000005.md](receipt-000005.md)

## 过程记录

- #2｜create｜Claude Code｜{"authority": {"basis": "用户在讨论 truth 文档方案时选择启用制图工具，同意联网安装约 400 MB 渲染依赖与安装制图提交钩子，并指示按“接入队列、启用制图工具、撰写三份 truth 文档”的方案执行，在本地 main 提交、不推送", "by": "用户"}, "deps": [], "id": "T1", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 运行环境满足 | `node --version` | 版本不低于 22.6 |\n| A2 | 图纸区三份规则在位、链接可解析 | 列出 `truth/architecture/`；逐条核对三份文件中的相对链接目标存在 | 三份文件在位；相对链接全部指向实存文件 |\n| A3 | 地图、工具清单、检查清单已登记 | 阅读根契约第 2 节、`tool/catalog.md`、`gate/checks.md` 的相应条目 | 三处条目齐全，描述与实际一致 |\n| A4 | 夹具与检查通过 | `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/render-diagrams-accept.mts` 与 `tool/diagram/check.mts` | 夹具无失败（层二未声明前允许 9 例 SKIP）；检查退出码 0 |\n| A5 | 渲染依赖可用 | `npm ci` 后用一份临时图源跑一次渲染，结束后删除临时文件 | 渲染成功产出 SVG；工作区不留临时产物 |\n| A6 | 提交钩子确实拦截 | 安装后暂存一处会让检查报红的临时改动并尝试提交，随后撤回该改动 | 提交被拒绝并给出制图检查提示；撤回后工作区无残留 |\n| A7 | 队列检查通过 | `python3 tool/shell.py doctor`；提交时的队列检查 | doctor 为 protection: ready、protocol: 2；提交检查通过 |\n\n验收安排：执行者逐项实跑并在回执中附原样命令、退出码与输出摘录，标“未独立验证”；用户审阅后决定是否通过。", "origin": "用户在讨论 truth 文档撰写方案时决定：启用模板随附的制图工具 `tool/diagram/`，用文本图源维护架构图并由程序核对图文一致；同意联网安装渲染依赖（约 400 MB）；同意安装制图提交钩子，并要求按“接入队列 → 启用制图工具 → 撰写三份 truth 文档”的方案执行，在本地 main 提交、不推送。\n\n目的：让随后撰写的 `truth/工程架构.md` 能以 mermaid 图源承载 C1、C2 架构图，渲染成 SVG，并在提交时机械核对图源、边表与产物一致。", "plan": "1. 核对 Node 版本与 Chrome 路径。\n2. 复制 `tool/diagram/zone/` 三件到 `truth/architecture/`，改写模板措辞与链接；《治理细则》第 7 节写本仓现状。\n3. 更新根契约地图、`tool/catalog.md`、`gate/checks.md`，设置 `registry.json` 的 `design_doc`。\n4. 跑夹具与检查。\n5. 在 `tool/diagram/` 运行 `npm ci`，用临时图源验证渲染，删除临时文件。\n6. 运行 `install-hook.sh`，用临时红改动试提交确认拦截，撤回。\n7. 写回执、交付，同批暂存账本、任务视图与本任务改动并提交。", "scope": "- 要交付：\n  - 图纸区 `truth/architecture/`：由 `tool/diagram/zone/` 复制的区契约、《架构设计与制图规范》《治理细则》三份，链接与“模板”措辞按复制后的位置改写；《治理细则》第 7 节写入本仓现状。\n  - 根契约第 2 节地图：新增图纸区一行；`tool/diagram/` 一行改为“已启用”。\n  - `tool/catalog.md`：制图工具从“可选工具”移到“项目专用工具”，写明用途、位置、来源与版本、前置条件、副作用、授权、验证与钩子安装方法。\n  - `gate/checks.md`：“项目专属检查”登记“架构图纸检查”一项。\n  - `tool/diagram/registry.json`：`settings.design_doc` 设为 `truth/工程架构.md`（该文件由后续撰写任务创建；声明 C1、C2 图名的 `l2_diagrams` 留给撰写任务）。\n  - 本机：在 `tool/diagram/` 运行 `npm ci` 安装渲染依赖；核对 `puppeteer-config.json` 的 Chrome 路径；运行 `sh tool/diagram/install-hook.sh` 接上提交钩子。\n- 不包含：任何架构图的绘制与 truth 正文文档的撰写；修改制图工具源码或队列工具；推送远端。\n- 允许修改的位置：`truth/architecture/`（新建）、`AGENTS.md` 第 2 节地图、`tool/catalog.md`、`gate/checks.md`、`tool/diagram/registry.json` 的 settings、`tool/diagram/puppeteer-config.json`（仅在 Chrome 路径不符时）；本机未入库的 `tool/diagram/node_modules/` 与 `.git/hooks/`。", "title": "启用制图工具"}}
- #4｜claim｜Claude Code｜{"expect": 2, "id": "T1"}
- #5｜deliver｜Claude Code｜{"artifacts": [{"path": "truth/architecture/AGENTS.md", "sha256": "ff6e512235977d7a8b99cc14a15dcceaa3f55dbc12470280f6a4693eb82723fd"}, {"path": "truth/architecture/架构设计与制图规范.md", "sha256": "810d25f781308c5d4e2e9040c17e3d462c71abcd1a94abc06f35d89d7ebf812d"}, {"path": "truth/architecture/治理细则.md", "sha256": "31a730548b113f6c3359e3a78cec18985894bdeb5c6254b98d6be3112dd7c550"}, {"path": "AGENTS.md", "sha256": "91279766447557723a938606a4f3569c4626eda2cdc46450abb182755e38e998"}, {"path": "tool/catalog.md", "sha256": "1d240fd72f306aa9d604b5acb2844d95f0ee539b4bf0f1df0022dd78c0691877"}, {"path": "gate/checks.md", "sha256": "49b5ab123c10dd9632689ab40a91bce608a62a9c43016a89023c887be00a6eb8"}, {"path": "tool/diagram/puppeteer-config.json", "sha256": "40ec33961cfc9ec7895ef02c8b22e3e0db8614d16fea122fd4e15330c38c0207"}], "expect": 4, "id": "T1", "receipt": "# 验证回执\n\n- 所属任务：T1 启用制图工具，见同卷 [task.md](task.md)。\n- 对应交付及版本：本次交付登记的工件（以 deliver 记录的指纹为准）：`truth/architecture/AGENTS.md`、`truth/architecture/架构设计与制图规范.md`、`truth/architecture/治理细则.md`、`AGENTS.md`、`tool/catalog.md`、`gate/checks.md`、`tool/diagram/puppeteer-config.json`；本机未入库：`tool/diagram/node_modules/`（含 `.chrome-headless-shell` 链接）、`.git/hooks/pre-commit`、`.git/hooks/pre-merge-commit`。\n- 验证时间、执行者：2026-10-01，Claude Code。\n- 独立性：未独立验证。\n\n## 逐项结果\n\n| 标准编号 | 实际操作与输入 | 结果 | 证据位置 |\n|---|---|---|---|\n| A1 | `node --version` | 满足：v24.21.0 | 下文命令型检查 1 |\n| A2 | 复制三份规则后列目录；用脚本逐条解析 6 份相关文件中的相对链接 | 满足：三份在位；63 条相对链接全部指向实存文件 | 下文命令型检查 2 |\n| A3 | 阅读根契约第 2 节、`tool/catalog.md`、`gate/checks.md` | 满足：地图新增图纸区一行、制图工具一行改为已启用；工具清单移入“项目专用工具”；检查清单登记“架构图纸检查” | 交付工件本身 |\n| A4 | 夹具 `render-diagrams-accept.mts`；检查 `check.mts` | 满足：PASS 17 · FAIL 0 · SKIP 9；检查退出码 0、无红 | 下文命令型检查 3 |\n| A5 | `npm ci`；临时图源 `truth/architecture/tmp-probe/tmp-probe.mmd` 渲染与可移植导出；结束后删除 | 满足（改用钉定的无界面浏览器之后）：渲染、导出退出码均为 0；临时件与两份清单已删除 | 下文命令型检查 4、5 |\n| A6 | `sh tool/diagram/install-hook.sh`；暂存缺设计说明的探针图并 `git commit` | 满足：提交被拒绝，提示“制图提交闸：拒绝提交（检查退出码 1）”；HEAD 未变；撤回后工作区无残留，检查无红 | 下文命令型检查 6 |\n| A7 | `python3 tool/shell.py doctor`；提交时的队列检查 | doctor 满足：protection: ready、protocol: 2。提交检查在本次交付提交时运行，结果随提交汇报给用户 | 下文命令型检查 7 |\n\n## 可复核的证据\n\n工作目录均为仓库根。\n\n1. `node --version` → `v24.21.0`，退出码 0。\n2. 链接核对脚本输出：`checked 63 relative links, missing 0`。\n3. `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/render-diagrams-accept.mts`，退出码 0，末行：`结果：PASS 17 · FAIL 0 · SKIP 9（前置设置未声明，不计通过）`；9 例 SKIP 均因层二图名尚未声明。`tool/diagram/check.mts`，退出码 0，末行：`无红。`\n4. `cd tool/diagram && npm ci`，退出码 0：`added 186 packages, and audited 187 packages in 16s`；另报 `2 moderate severity vulnerabilities`；并提示 `puppeteer@25.3.0 (postinstall: node install.mjs)` 的安装脚本未被允许运行。`du -sh node_modules` → `403M`。\n5. 以默认的 `/Applications/Google Chrome.app/.../Google Chrome`（版本 154.0.8037.59）导出时，`export-portable-svg.mts` 抛出 `Command failed: ... --headless --disable-gpu --dump-dom ...`，`status: 2`，而 stdout 已含正确的 DOM。单独复现：同一命令对一个最小 HTML 输出正确内容，但退出码为 2，stderr 末尾为 `Teardown watchdog expired; recording dump and terminating.`；在命令沙箱外重跑结果相同。puppeteer 25.3.0 钉定的 `chrome-headless-shell` 150.0.7871.24 已在本机 `~/.cache/puppeteer/`，同一命令退出码 0。于是把 `puppeteer-config.json` 的 `executablePath` 改为相对仓库根的 `tool/diagram/node_modules/.chrome-headless-shell/chrome-headless-shell-mac-arm64/chrome-headless-shell`，并建立链接 `ln -sfn ~/.cache/puppeteer/chrome-headless-shell/mac_arm-150.0.7871.24 tool/diagram/node_modules/.chrome-headless-shell`。之后删除探针 SVG 重渲：`已渲染：tmp-probe/tmp-probe.svg`，退出码 0；`已导出：tmp-probe/portable/tmp-probe-portable.svg`，退出码 0。\n6. `sh tool/diagram/install-hook.sh` → `已接上：.../.git/hooks/pre-commit`、`已接上：.../.git/hooks/pre-merge-commit`，退出码 0。暂存探针后 `git commit -m \"probe: should be rejected\"`，退出码 1，输出含 `红 (w) 架构图文对齐：tmp-probe：图源无配对详设文档` 与 `制图提交闸：拒绝提交（检查退出码 1）`；`git log --oneline -1` 仍为 `b4b84b2`。随后 `git reset -- truth/architecture`，删除探针目录与两份清单；`check.mts` 退出码 0，`无红。`\n7. `python3 tool/shell.py doctor` → `{\"ok\": true, \"protection\": \"ready\", \"seq\": 4, \"tasks\": 2, \"protocol\": 2}`。\n\n## 未满足项与限制\n\n- 范围偏差：方案要交付“`settings.design_doc` 设为 `truth/工程架构.md`”。实测一经登记，检查就要求该文档在位，否则报红（`设计文档不在位：truth/工程架构.md`），与 A4 冲突；方案中“文件不在位时跳过”的假设不成立。故 T1 未登记 `design_doc`，改由 T2 随文档一并登记（T2 获准修改 `registry.json` 的 settings）。`tool/catalog.md` 与《治理细则》第 7 节已按此如实描述。\n- 计划外改动：因本机 Chrome 154 的退出码问题，修改了 `tool/diagram/puppeteer-config.json`（方案允许“仅在 Chrome 路径不符时”修改），并在本机 `node_modules/` 建立浏览器链接；做法写进了 `tool/catalog.md`。`npm ci` 会清空 `node_modules/`，之后须重建链接。`npx puppeteer browsers install chrome-headless-shell` 的下载路径未实测。\n- 依赖安全：`npm ci` 报 2 个中等风险的依赖漏洞，未处理（处理须改依赖钉版，超出本任务范围）。\n- 范围外发现（未改动）：`tool/AGENTS.md` 仍以“默认不启用，列在可选工具里”举例制图工具；`tool/diagram/AGENTS.md` 启用步骤 5 仍以 macOS 上的 Google Chrome 为默认浏览器，未提 Chrome 154 的退出码问题；《架构设计与制图规范》第 1 节的“读法对照”表留待 T2 撰写工程架构时填写。\n\n本件记录检查事实，不代替用户最终验收。\n", "summary": "建立图纸区并登记工具与检查；装好渲染依赖与提交钩子并实测拦截；因 Chrome 154 退出码问题改用钉定的无界面浏览器；design_doc 改由 T2 随文档登记", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
