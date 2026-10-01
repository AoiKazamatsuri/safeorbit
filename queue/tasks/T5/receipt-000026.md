# 验证回执

- 所属任务：T5，见同卷 [task.md](task.md)；验收依据为批准基线 approval-001.md。
- 对应交付及版本：本次 deliver 登记的工件 `queue/AGENTS.md`，以登记的指纹为准。
- 验证时间、执行者：2026-10-01，Claude Code。
- 独立性：未独立验证。读数由执行者自跑自核。

## 逐项结果

| 标准编号 | 实际操作与输入 | 结果 | 证据位置 |
|---|---|---|---|
| E1 | 在 `queue/AGENTS.md`“一致性”一节第一段后新增一段，通读 | 满足：写明请求号一笔操作一个、重试沿用原号、新操作用新号且旧号不复用；同一任务同种操作再做一次（释放后再领取、返工后再交付、换会话接手）是新操作，沿用旧号会被拒；同日按“编号-操作-日期”取号须加会话或轮次标记，附实例 | `queue/AGENTS.md` |
| E2 | `git -c core.quotepath=false grep -n -E '请求号\|request' -- '*.md' ':!queue/tasks' ':!reference' ':!CHANGELOG.md'` 逐行核对 | 满足：与根契约第 7 条（请求号做法见队列规则“一致性”）、`tool/AGENTS.md`“稳定请求号防止重复落账”、`tool/queue-usage.md`“同号同业务输入重试返回原操作……同号不同业务输入拒绝”一致，无矛盾 | 下文命令 1 |
| E3 | doctor；提交时队列检查 | doctor 满足；提交检查在本次交付提交时运行，结果随提交汇报给用户 | 下文命令 2 |

## 可复核的证据

工作目录为仓库根；队列命令使用 init 记录的解释器 `/opt/anaconda3/bin/python3`。

1. 上述 grep 命中 `AGENTS.md` 第 85 行（第 7 条）、`queue/AGENTS.md` 第 35 行、`tool/AGENTS.md` 第 18 行、`tool/queue-usage.md` 第 32、63、68、92–94、98、100、152 行；逐行阅读，均为“带稳定请求号”“重试沿用原号”“同号不同输入拒绝”的说法，与新增段落相容。新增段落中的相对链接检查：`checked 3 relative links in 1 files, missing 0`，退出码 0。
2. `python3 tool/shell.py doctor`，退出码 0：`{"ok": true, "protection": "ready", "seq": 25, "tasks": 5, "protocol": 2}`。
3. 依据实例：本会话领取 T3 时用请求号 `T3-claim-20261001`（上个会话第 17 笔领取已用此号，当时 expect 为 16），返回 `{"ok": false, "code": "idempotency", "message": "同一请求号对应不同输入；拒绝重复执行，请核对原请求。", "committed": false}`，退出码 1；改用 `T3-claim-20261001-session2` 后领取成功（第 19 笔）。

## 未满足项与限制

无未满足的验收标准。

- `tool/queue-usage.md`“快速收尾”示例的请求号写法 `<乙>-claim-<日期>` 在同日重复操作时会撞号；它是模板机制文件，本任务按范围未改，新增段落已写明同日加区分标记的做法。

本件记录检查事实，不代替用户最终验收。
