# 验证回执（第二次交付）

- 所属任务：T1 启用制图工具，见同卷 [task.md](task.md)。首次交付的完整证据见同卷 [receipt-000005.md](receipt-000005.md)。
- 对应交付及版本：本次 deliver 登记的工件，以记录的指纹为准：`AGENTS.md`、`gate/checks.md`、`tool/catalog.md`、`tool/diagram/puppeteer-config.json`、`truth/architecture/AGENTS.md`。这五个文件与首次交付所在提交 b683c4d 逐字相同。
- 验证时间、执行者：2026-10-01，Claude Code。
- 独立性：未独立验证。

## 重新交付的原因

首次交付后，任务 T2 在其批准范围内修改了图纸区的两份细则：《架构设计与制图规范》第 1 节读法表与《治理细则》第 7 节现状。两份文件的指纹因此不再等于 T1 首次交付的版本，T1 无法凭旧证据记通过。两份细则的现行版本已作为 T2 的交付工件登记，由 T2 的验收覆盖；T1 本次只交付未被改动的五个文件。T1 的实质内容没有变化。

## 逐项结果

| 标准编号 | 实际操作与输入 | 结果 | 证据位置 |
|---|---|---|---|
| A1 | `node --version` | 满足：v24.21.0 | 下文 1 |
| A2 | 三份规则在位；链接核对见首次回执；本次核对五个工件未变 | 满足：`truth/architecture/` 下三份规则在位；五个工件与 b683c4d 无差异 | 下文 2 |
| A3 | 根契约地图、工具清单、检查清单 | 满足：与首次交付相同 | 下文 2 |
| A4 | `tool/diagram/check.mts` | 满足：退出码 0、无红（现已含 T2 的三张图） | 下文 3 |
| A5 | 渲染依赖 | 满足：T2 期间多次渲染与导出均退出码 0，见 T2 回执 | T2 回执 |
| A6 | 提交钩子 | 满足：`.git/hooks/` 下 `pre-commit`、`pre-merge-commit` 在位；T2 提交时钩子实际运行并放行无红的暂存内容 | 下文 4 |
| A7 | doctor | 满足：protection: ready、protocol: 2 | 下文 5 |

## 可复核的证据

工作目录为仓库根。

1. `node --version` → `v24.21.0`。
2. `git diff --stat b683c4d -- AGENTS.md gate/checks.md tool/catalog.md tool/diagram/puppeteer-config.json truth/architecture/AGENTS.md`，无输出，退出码 0。对照：`git diff --stat b683c4d -- truth/architecture/架构设计与制图规范.md truth/architecture/治理细则.md` 显示两份文件共 14 行增、13 行删，均为 T2 的修订。
3. `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 末行 `无红。`，退出码 0。
4. `ls .git/hooks` 列出 `pre-commit`、`pre-merge-commit`；T2 的提交 9beee95 输出中有 `制图检查（暂存区）` 与 `无红。`。
5. `python3 tool/shell.py doctor` → `{"ok": true, "protection": "ready", "seq": 8, "tasks": 2, "protocol": 2}`。

## 未满足项与限制

- 首次回执列出的范围偏差（`design_doc` 改由 T2 登记，已于 T2 完成）、浏览器改用 chrome-headless-shell、2 个中等风险的依赖漏洞与范围外发现，均仍然成立，不再重复。

本件记录检查事实，不代替用户最终验收。
