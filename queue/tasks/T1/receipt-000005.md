# 验证回执

- 所属任务：T1 启用制图工具，见同卷 [task.md](task.md)。
- 对应交付及版本：本次交付登记的工件（以 deliver 记录的指纹为准）：`truth/architecture/AGENTS.md`、`truth/architecture/架构设计与制图规范.md`、`truth/architecture/治理细则.md`、`AGENTS.md`、`tool/catalog.md`、`gate/checks.md`、`tool/diagram/puppeteer-config.json`；本机未入库：`tool/diagram/node_modules/`（含 `.chrome-headless-shell` 链接）、`.git/hooks/pre-commit`、`.git/hooks/pre-merge-commit`。
- 验证时间、执行者：2026-10-01，Claude Code。
- 独立性：未独立验证。

## 逐项结果

| 标准编号 | 实际操作与输入 | 结果 | 证据位置 |
|---|---|---|---|
| A1 | `node --version` | 满足：v24.21.0 | 下文命令型检查 1 |
| A2 | 复制三份规则后列目录；用脚本逐条解析 6 份相关文件中的相对链接 | 满足：三份在位；63 条相对链接全部指向实存文件 | 下文命令型检查 2 |
| A3 | 阅读根契约第 2 节、`tool/catalog.md`、`gate/checks.md` | 满足：地图新增图纸区一行、制图工具一行改为已启用；工具清单移入“项目专用工具”；检查清单登记“架构图纸检查” | 交付工件本身 |
| A4 | 夹具 `render-diagrams-accept.mts`；检查 `check.mts` | 满足：PASS 17 · FAIL 0 · SKIP 9；检查退出码 0、无红 | 下文命令型检查 3 |
| A5 | `npm ci`；临时图源 `truth/architecture/tmp-probe/tmp-probe.mmd` 渲染与可移植导出；结束后删除 | 满足（改用钉定的无界面浏览器之后）：渲染、导出退出码均为 0；临时件与两份清单已删除 | 下文命令型检查 4、5 |
| A6 | `sh tool/diagram/install-hook.sh`；暂存缺设计说明的探针图并 `git commit` | 满足：提交被拒绝，提示“制图提交闸：拒绝提交（检查退出码 1）”；HEAD 未变；撤回后工作区无残留，检查无红 | 下文命令型检查 6 |
| A7 | `python3 tool/shell.py doctor`；提交时的队列检查 | doctor 满足：protection: ready、protocol: 2。提交检查在本次交付提交时运行，结果随提交汇报给用户 | 下文命令型检查 7 |

## 可复核的证据

工作目录均为仓库根。

1. `node --version` → `v24.21.0`，退出码 0。
2. 链接核对脚本输出：`checked 63 relative links, missing 0`。
3. `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/render-diagrams-accept.mts`，退出码 0，末行：`结果：PASS 17 · FAIL 0 · SKIP 9（前置设置未声明，不计通过）`；9 例 SKIP 均因层二图名尚未声明。`tool/diagram/check.mts`，退出码 0，末行：`无红。`
4. `cd tool/diagram && npm ci`，退出码 0：`added 186 packages, and audited 187 packages in 16s`；另报 `2 moderate severity vulnerabilities`；并提示 `puppeteer@25.3.0 (postinstall: node install.mjs)` 的安装脚本未被允许运行。`du -sh node_modules` → `403M`。
5. 以默认的 `/Applications/Google Chrome.app/.../Google Chrome`（版本 154.0.8037.59）导出时，`export-portable-svg.mts` 抛出 `Command failed: ... --headless --disable-gpu --dump-dom ...`，`status: 2`，而 stdout 已含正确的 DOM。单独复现：同一命令对一个最小 HTML 输出正确内容，但退出码为 2，stderr 末尾为 `Teardown watchdog expired; recording dump and terminating.`；在命令沙箱外重跑结果相同。puppeteer 25.3.0 钉定的 `chrome-headless-shell` 150.0.7871.24 已在本机 `~/.cache/puppeteer/`，同一命令退出码 0。于是把 `puppeteer-config.json` 的 `executablePath` 改为相对仓库根的 `tool/diagram/node_modules/.chrome-headless-shell/chrome-headless-shell-mac-arm64/chrome-headless-shell`，并建立链接 `ln -sfn ~/.cache/puppeteer/chrome-headless-shell/mac_arm-150.0.7871.24 tool/diagram/node_modules/.chrome-headless-shell`。之后删除探针 SVG 重渲：`已渲染：tmp-probe/tmp-probe.svg`，退出码 0；`已导出：tmp-probe/portable/tmp-probe-portable.svg`，退出码 0。
6. `sh tool/diagram/install-hook.sh` → `已接上：.../.git/hooks/pre-commit`、`已接上：.../.git/hooks/pre-merge-commit`，退出码 0。暂存探针后 `git commit -m "probe: should be rejected"`，退出码 1，输出含 `红 (w) 架构图文对齐：tmp-probe：图源无配对详设文档` 与 `制图提交闸：拒绝提交（检查退出码 1）`；`git log --oneline -1` 仍为 `b4b84b2`。随后 `git reset -- truth/architecture`，删除探针目录与两份清单；`check.mts` 退出码 0，`无红。`
7. `python3 tool/shell.py doctor` → `{"ok": true, "protection": "ready", "seq": 4, "tasks": 2, "protocol": 2}`。

## 未满足项与限制

- 范围偏差：方案要交付“`settings.design_doc` 设为 `truth/工程架构.md`”。实测一经登记，检查就要求该文档在位，否则报红（`设计文档不在位：truth/工程架构.md`），与 A4 冲突；方案中“文件不在位时跳过”的假设不成立。故 T1 未登记 `design_doc`，改由 T2 随文档一并登记（T2 获准修改 `registry.json` 的 settings）。`tool/catalog.md` 与《治理细则》第 7 节已按此如实描述。
- 计划外改动：因本机 Chrome 154 的退出码问题，修改了 `tool/diagram/puppeteer-config.json`（方案允许“仅在 Chrome 路径不符时”修改），并在本机 `node_modules/` 建立浏览器链接；做法写进了 `tool/catalog.md`。`npm ci` 会清空 `node_modules/`，之后须重建链接。`npx puppeteer browsers install chrome-headless-shell` 的下载路径未实测。
- 依赖安全：`npm ci` 报 2 个中等风险的依赖漏洞，未处理（处理须改依赖钉版，超出本任务范围）。
- 范围外发现（未改动）：`tool/AGENTS.md` 仍以“默认不启用，列在可选工具里”举例制图工具；`tool/diagram/AGENTS.md` 启用步骤 5 仍以 macOS 上的 Google Chrome 为默认浏览器，未提 Chrome 154 的退出码问题；《架构设计与制图规范》第 1 节的“读法对照”表留待 T2 撰写工程架构时填写。

本件记录检查事实，不代替用户最终验收。
