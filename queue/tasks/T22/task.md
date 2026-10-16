# 队列工具提速：重放时不再整份复制全部任务

```json
{
  "id": "T22",
  "revision": 614,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "通过"
}
```

## 登记依据

本机用 init 记录的解释器 `/opt/anaconda3/bin/python3` 运行队列工具，`doctor`、`task status`、`state get` 等只读命令每条约 35–40 秒，写一笔账约 1–1.5 分钟。排查（cProfile 与分段计时）：每条命令要把机器账的全部 609 笔事件从头重放 3 遍（写一笔账约 8 遍），单遍约 12 秒；`tool/queue_v2.py` 的 `apply` 对每笔事件都用 `copy.deepcopy` 把截至当时的全部任务（含每件任务的完整历史正文）整份复制两次——一次是旧格式视图 `legacy()`，一次是只为读原状态的 `before`——重放耗时随账本长度平方增长，99% 的时间花在复制上。另外 `task status` 每列一件任务都把全部任务视图重新生成一遍。本机的模板副本 `../devtemplate`（最新提交 2d423a9，2026-10-03）没有这方面的修复；用户决定不联网查 GitHub 上游，直接按本方案改。

用户明确指令：在不改变任何行为和输出的前提下让队列工具变快；同意本方案，并加守护测试。临时克隆中的原型读数：doctor 35.1 秒降到 0.41 秒，task status 38.5 秒降到 0.46 秒，state get 38.1 秒降到 0.89 秒，输出与旧版逐字节相同。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000612.md](receipt-000612.md)

## 过程记录

- #610｜create｜Claude Code｜{"authority": {"basis": "用户明确指令：在不改变任何行为和输出的前提下让队列工具变快；不联网查上游模板，按方案实施并加守护测试。", "by": "用户"}, "deps": [], "id": "T22", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 真实账本的重放结果不变 | 旧版与新版并排逐笔重放本仓机器账的全部事件，每笔之后比对全部任务内容、协议、配置与编号版本；最后比对全部生成视图与每件任务的就绪判断 | 每一步完全相同 |\n| A2 | 只读命令输出不变 | 在本仓的临时克隆中，旧版、新版分别运行 doctor、task status（全部与单件）、task history（全部与单件）、state get、state check、config show、check --staged、repair | 标准输出、错误输出与退出码逐字节相同 |\n| A3 | 写命令行为不变 | 两个临时克隆从同一提交出发，分别用旧版、新版跑同一串写操作（登记、批准、领取、改计划、交接、交付、返工、改范围、通过、让出、撤销、取消）与若干应被拒绝的输入 | 每条命令的输出与退出码相同；账本除事件时间外相同；全部任务文件逐字节相同 |\n| A4 | 队列工具测试全部通过 | `/opt/anaconda3/bin/python3 -B -m unittest discover -s gate -p 'test_*.py'` | 退出码 0，含新增守护测试 |\n| A5 | 明显变快 | 同一解释器在本仓运行同一组命令，记下改动前后的原样耗时 | doctor、task status、state get 各在 3 秒以内；写一笔账在 10 秒以内 |\n| A6 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；提交时的队列检查 | 仅授权文件；检查退出码 0 |\n\n验收安排：A1–A6 由执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”；用户验收。", "origin": "本机用 init 记录的解释器 `/opt/anaconda3/bin/python3` 运行队列工具，`doctor`、`task status`、`state get` 等只读命令每条约 35–40 秒，写一笔账约 1–1.5 分钟。排查（cProfile 与分段计时）：每条命令要把机器账的全部 609 笔事件从头重放 3 遍（写一笔账约 8 遍），单遍约 12 秒；`tool/queue_v2.py` 的 `apply` 对每笔事件都用 `copy.deepcopy` 把截至当时的全部任务（含每件任务的完整历史正文）整份复制两次——一次是旧格式视图 `legacy()`，一次是只为读原状态的 `before`——重放耗时随账本长度平方增长，99% 的时间花在复制上。另外 `task status` 每列一件任务都把全部任务视图重新生成一遍。本机的模板副本 `../devtemplate`（最新提交 2d423a9，2026-10-03）没有这方面的修复；用户决定不联网查 GitHub 上游，直接按本方案改。\n\n用户明确指令：在不改变任何行为和输出的前提下让队列工具变快；同意本方案，并加守护测试。临时克隆中的原型读数：doctor 35.1 秒降到 0.41 秒，task status 38.5 秒降到 0.46 秒，state get 38.1 秒降到 0.89 秒，输出与旧版逐字节相同。", "plan": "1. 写账前比对远端，登记并批准、领取，同批提交并推送。\n2. 在临时克隆中实施改动与守护测试，跑 A1–A4。\n3. 合入主工作树，跑 A4–A6，记下前后耗时；写回执交付，同批提交并推送，提醒另一克隆拉取。", "scope": "- 要交付：\n  - `tool/queue_v2.py`：`legacy()` 改为逐件任务复制一层，另行复制旧版逻辑会原地修改的依赖、批准基线、回执、历史四个列表与方案；列表里的事件、基线、回执记录只读共用，不再复制。`apply()` 中的 `before` 改为只记各任务原来的状态。\n  - `tool/task_queue.py`：`response_files()` 把全部任务视图生成一次供各行共用，不再每行重新生成。\n  - `gate/test_task_queue.py`：新增守护测试，核对重放不改动账本事件本身、被拒绝的事件不改动既有任务状态——新的复制方式依赖这两点，日后有人改旧格式逻辑时能拦住。\n  - `tool/AGENTS.md`“与模板的差异”表登记上述三个文件的改动。\n- 不包含：重放结果缓存；减少每条命令的重放次数；命令、参数、输出格式与账本格式；其他规则与用法文档；与模板副本 2d423a9 的同步；`object/` 下任何文件。\n- 允许修改的位置：`tool/queue_v2.py`、`tool/task_queue.py`、`gate/test_task_queue.py`、`tool/AGENTS.md`（仅差异表）。队列记录只经工具维护。", "title": "队列工具提速：重放时不再整份复制全部任务"}}
- #611｜claim｜Claude Code｜{"expect": 610, "id": "T22"}
- #612｜deliver｜Claude Code｜{"artifacts": [{"path": "tool/queue_v2.py", "sha256": "6afd625b4aabf7c73dfe8c5489e5b70e061c3d2bf62bc711349df5de7faff60f"}, {"path": "tool/task_queue.py", "sha256": "3d0f152d6cc8b251f3d39cd2a4ccd2deb69723ea231d7f3be6334e19787b7d39"}, {"path": "gate/test_task_queue.py", "sha256": "2c20b55c68c4f440813fc73d8fc95383fee5cbd0cf029b45a2610195b0afd0a3"}, {"path": "tool/AGENTS.md", "sha256": "617036b7e7e30b498467aaeaf14eae55ff54d5fd8360655f348fa4c761459ec0"}], "expect": 611, "id": "T22", "receipt": "# T22 交付回执\n\n按批准方案去掉队列工具重放时的整份复制，并让 `task status` 只生成一次任务视图；新增一个守护测试，在“与模板的差异”登记。改动与验证都由执行者完成，没有派子代理。验证未独立验证，尚未由用户验收。\n\n## 实际修改\n\n- `tool/queue_v2.py`：\n  - `legacy()`：原来每次都用 `copy.deepcopy` 整份复制全部任务（含历史正文）；改为逐件任务复制一层，另行复制旧格式逻辑会原地修改的 `deps`、`approvals`、`receipts`、`history` 四个列表与 `proposal`，列表里的事件、批准基线与回执记录只读共用。\n  - `apply()`：`before` 原来整份深复制、只用来读各任务原来的状态，改为只记状态。\n- `tool/task_queue.py`：`response_files()` 先把全部任务视图生成一次，各行从中筛出自己的文件清单；原来每列一件任务就重新生成一遍。没有行要列时不生成，与原来一致。\n- `gate/test_task_queue.py`：新增 `test_63_replay_shares_records_read_only_and_rejected_events_change_nothing`。先用真实命令走一遍登记、领取、改计划、交接、交付、返工、改范围、重交、通过、让出、撤销、取消，再在子进程里核对：重放前后账本事件本身不变，两次重放结果相同；四种被拒绝的事件（成环的修订、没有工件的交付、非认领者改计划、对已通过任务再通过）都不改动任务状态。另用旧代码和两个故意改坏的版本核对这个测试：旧代码通过；去掉依赖列表的复制并让关系修改原地进行时，以 `rejected revise changed tasks` 失败；冻结新基线时原地改上一轮授权时，测试同样失败。\n- `tool/AGENTS.md`：“与模板的差异”表新增三行，对应上述三个文件，任务 T22。\n- 没有新增依赖；命令、参数、输出与账本格式不变。\n\n## 验证\n\nA1 真实账本逐笔对照：脚本 `a1_digest.py`（会话临时目录）分别用旧版（提交 1e30c1c 的 `tool/`）与新版重放，每笔事件之后对全部任务、协议、配置与编号版本的 JSON 取 SHA-256 摘要；最后比对全部生成视图、每件任务的就绪判断与窗口占用。用了两份账：本仓 HEAD 的机器账（611 笔），以及 A3 新版克隆写完后的账（630 笔，多出改范围、让出、撤销、取消、子树取消等操作）。结果原样：\n\n```text\nreal events 611 steps 611 611 steps identical True final True projections True 408 blockers True occupied True ['T21', 'T22']\nextended events 630 steps 630 630 steps identical True final True projections True 425 blockers True occupied True ['T21', 'T22']\n```\n\nA2、A3 只读与写命令对照：从提交 1e30c1c 克隆两份临时仓库，一份保持旧版工具，一份换上新版（已暂存），用同一驱动脚本 `a3_driver.py` 各跑 68 步：init、doctor、task status（全部、单件、不存在的编号）、task history（全部、单件）、state get、state check（有效与无效版本）、config show、repair、check --staged；随后 19 笔写入（登记、修订、批准、领取、改计划、交接、交付、返工、改范围、重交、通过、登记并批准、他人领取、让出、撤销、取消、带依赖登记、带父任务登记、子树取消），1 次同号重试，6 次应被拒绝的输入（领取中的任务通过、领取已被认领的任务、修订已封存任务、非认领者交付、依赖不存在、过期状态版本）；最后再跑一遍读命令，暂存后 check --staged。比对脚本 `a3_compare.py` 退出码 0，输出原样：\n\n```text\nsteps identical byte for byte: 15; identical after masking times and state versions: 53\nmanaged files identical: 426; ledger events identical except at/context: 630\nA3 COMPARE OK\n```\n\n首次写入之前的 15 步（含 A2 列出的全部只读命令）标准输出、错误输出与退出码逐字节相同，只有克隆路径不同。之后两边账本的事件时间不同，由账本派生的状态版本号也随之不同，比对时只屏蔽事件时间 `at`、状态版本 `context` 与 `edit_token`，其余输出与退出码全部相同；6 次拒绝在两边都以同一错误码（acceptance、not_ready、sealed、owner、graph、stale_context）退出 1。全部任务文件逐字节相同；两份账本除事件时间与状态版本外相同。\n\nA4：\n\n```sh\n/opt/anaconda3/bin/python3 -B -m unittest discover -s gate -p 'test_*.py'\n```\n\n主工作树退出码 0，原样结尾 `Ran 103 tests in 188.492s` 与 `OK`（原有 102 项加新增 1 项）。临时克隆中先跑过一次：`Ran 103 tests in 201.747s`、`OK`。\n\nA5 前后耗时，同一解释器 `/opt/anaconda3/bin/python3`，取 zsh `time` 的 total：\n\n| 命令 | 改动前（主工作树） | 改动后 |\n|---|---|---|\n| doctor | 36.071 秒 | 0.458 秒（主工作树） |\n| task status | 39.723 秒 | 0.459 秒（主工作树） |\n| state get | 37.363 秒 | 0.909 秒（主工作树） |\n| 写一笔账 | register 1:41.78、claim 1:36.79 | register 1.46 秒、claim 1.47 秒（A3 新版克隆，同一份账） |\n| 提交检查 check --staged | 1:43.84（T22 登记提交的钩子） | 5.258 秒（主工作树，暂存本次四个文件后） |\n\nA3 两个临时克隆的逐条读数：旧版读命令每条 35.8–40.9 秒、写一笔 97.8–111.7 秒、check --staged 103.5–105.7 秒；新版读命令每条 0.34–0.97 秒、写一笔 1.46–1.60 秒、check --staged 5.00–5.12 秒。68 步合计旧版 4054 秒、新版 71 秒。\n\nA6：\n\n```sh\ngit diff --check\ngit diff --stat\n```\n\n前者退出码 0、输出为空；后者原样为 4 个文件（`gate/test_task_queue.py`、`tool/AGENTS.md`、`tool/queue_v2.py`、`tool/task_queue.py`），69 行新增、7 行删除。提交时的队列检查在本次交付提交中运行。\n\n## 说明与风险\n\n- 上游未联网核查：用户决定不查 GitHub 上的模板源仓。本机模板副本 `../devtemplate` 的最新提交 2d423a9（2026-10-03）没有提速修复；它另修了一处与本任务无关的问题（任务正文含 U+2028 等特殊换行符时，账本会被判为不可解析），本项目尚未同步，不在本任务范围。日后同步模板时，按“与模板的差异”重放本次三处改动。\n- 守护测试里“被拒绝的事件不改动任务”，覆盖的是旧格式规则与交付、通过前置检查里的拒绝。超出窗口容量的拒绝发生在任务表更新之后，新旧代码一样；任何拒绝都会让整次重放作废，命令看不到中间状态。\n- 每条命令仍重放 3 遍（写一笔约 8 遍），单遍约 0.07 秒，耗时现在随账本长度线性增长。提交检查剩下的约 5 秒主要花在逐个文件调用 `git cat-file`，本任务未动。\n- 另一个克隆须先拉取本次提交再写账。新旧工具写出的记录完全相同，只是旧工具仍慢。\n- 对照脚本、两个临时克隆与日志都在会话临时目录，不入库。\n", "summary": "重放不再整份复制全部任务，task status 只生成一次视图，新增守护测试；新旧版本逐笔与逐命令对照一致，gate 103 项通过；只读命令约 36–40 秒降到 0.5–0.9 秒，写一笔账约 1.6 分钟降到约 1.5 秒；未独立验证。", "verification": "passed"}
- #614｜close｜Claude Code｜{"authority": {"basis": "用户明确指令：验收通过 T22（队列工具提速），记为通过，然后继续领取并完成 T23。", "by": "用户"}, "expect": 612, "id": "T22"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
