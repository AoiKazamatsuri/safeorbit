# T22 交付回执

按批准方案去掉队列工具重放时的整份复制，并让 `task status` 只生成一次任务视图；新增一个守护测试，在“与模板的差异”登记。改动与验证都由执行者完成，没有派子代理。验证未独立验证，尚未由用户验收。

## 实际修改

- `tool/queue_v2.py`：
  - `legacy()`：原来每次都用 `copy.deepcopy` 整份复制全部任务（含历史正文）；改为逐件任务复制一层，另行复制旧格式逻辑会原地修改的 `deps`、`approvals`、`receipts`、`history` 四个列表与 `proposal`，列表里的事件、批准基线与回执记录只读共用。
  - `apply()`：`before` 原来整份深复制、只用来读各任务原来的状态，改为只记状态。
- `tool/task_queue.py`：`response_files()` 先把全部任务视图生成一次，各行从中筛出自己的文件清单；原来每列一件任务就重新生成一遍。没有行要列时不生成，与原来一致。
- `gate/test_task_queue.py`：新增 `test_63_replay_shares_records_read_only_and_rejected_events_change_nothing`。先用真实命令走一遍登记、领取、改计划、交接、交付、返工、改范围、重交、通过、让出、撤销、取消，再在子进程里核对：重放前后账本事件本身不变，两次重放结果相同；四种被拒绝的事件（成环的修订、没有工件的交付、非认领者改计划、对已通过任务再通过）都不改动任务状态。另用旧代码和两个故意改坏的版本核对这个测试：旧代码通过；去掉依赖列表的复制并让关系修改原地进行时，以 `rejected revise changed tasks` 失败；冻结新基线时原地改上一轮授权时，测试同样失败。
- `tool/AGENTS.md`：“与模板的差异”表新增三行，对应上述三个文件，任务 T22。
- 没有新增依赖；命令、参数、输出与账本格式不变。

## 验证

A1 真实账本逐笔对照：脚本 `a1_digest.py`（会话临时目录）分别用旧版（提交 1e30c1c 的 `tool/`）与新版重放，每笔事件之后对全部任务、协议、配置与编号版本的 JSON 取 SHA-256 摘要；最后比对全部生成视图、每件任务的就绪判断与窗口占用。用了两份账：本仓 HEAD 的机器账（611 笔），以及 A3 新版克隆写完后的账（630 笔，多出改范围、让出、撤销、取消、子树取消等操作）。结果原样：

```text
real events 611 steps 611 611 steps identical True final True projections True 408 blockers True occupied True ['T21', 'T22']
extended events 630 steps 630 630 steps identical True final True projections True 425 blockers True occupied True ['T21', 'T22']
```

A2、A3 只读与写命令对照：从提交 1e30c1c 克隆两份临时仓库，一份保持旧版工具，一份换上新版（已暂存），用同一驱动脚本 `a3_driver.py` 各跑 68 步：init、doctor、task status（全部、单件、不存在的编号）、task history（全部、单件）、state get、state check（有效与无效版本）、config show、repair、check --staged；随后 19 笔写入（登记、修订、批准、领取、改计划、交接、交付、返工、改范围、重交、通过、登记并批准、他人领取、让出、撤销、取消、带依赖登记、带父任务登记、子树取消），1 次同号重试，6 次应被拒绝的输入（领取中的任务通过、领取已被认领的任务、修订已封存任务、非认领者交付、依赖不存在、过期状态版本）；最后再跑一遍读命令，暂存后 check --staged。比对脚本 `a3_compare.py` 退出码 0，输出原样：

```text
steps identical byte for byte: 15; identical after masking times and state versions: 53
managed files identical: 426; ledger events identical except at/context: 630
A3 COMPARE OK
```

首次写入之前的 15 步（含 A2 列出的全部只读命令）标准输出、错误输出与退出码逐字节相同，只有克隆路径不同。之后两边账本的事件时间不同，由账本派生的状态版本号也随之不同，比对时只屏蔽事件时间 `at`、状态版本 `context` 与 `edit_token`，其余输出与退出码全部相同；6 次拒绝在两边都以同一错误码（acceptance、not_ready、sealed、owner、graph、stale_context）退出 1。全部任务文件逐字节相同；两份账本除事件时间与状态版本外相同。

A4：

```sh
/opt/anaconda3/bin/python3 -B -m unittest discover -s gate -p 'test_*.py'
```

主工作树退出码 0，原样结尾 `Ran 103 tests in 188.492s` 与 `OK`（原有 102 项加新增 1 项）。临时克隆中先跑过一次：`Ran 103 tests in 201.747s`、`OK`。

A5 前后耗时，同一解释器 `/opt/anaconda3/bin/python3`，取 zsh `time` 的 total：

| 命令 | 改动前（主工作树） | 改动后 |
|---|---|---|
| doctor | 36.071 秒 | 0.458 秒（主工作树） |
| task status | 39.723 秒 | 0.459 秒（主工作树） |
| state get | 37.363 秒 | 0.909 秒（主工作树） |
| 写一笔账 | register 1:41.78、claim 1:36.79 | register 1.46 秒、claim 1.47 秒（A3 新版克隆，同一份账） |
| 提交检查 check --staged | 1:43.84（T22 登记提交的钩子） | 5.258 秒（主工作树，暂存本次四个文件后） |

A3 两个临时克隆的逐条读数：旧版读命令每条 35.8–40.9 秒、写一笔 97.8–111.7 秒、check --staged 103.5–105.7 秒；新版读命令每条 0.34–0.97 秒、写一笔 1.46–1.60 秒、check --staged 5.00–5.12 秒。68 步合计旧版 4054 秒、新版 71 秒。

A6：

```sh
git diff --check
git diff --stat
```

前者退出码 0、输出为空；后者原样为 4 个文件（`gate/test_task_queue.py`、`tool/AGENTS.md`、`tool/queue_v2.py`、`tool/task_queue.py`），69 行新增、7 行删除。提交时的队列检查在本次交付提交中运行。

## 说明与风险

- 上游未联网核查：用户决定不查 GitHub 上的模板源仓。本机模板副本 `../devtemplate` 的最新提交 2d423a9（2026-10-03）没有提速修复；它另修了一处与本任务无关的问题（任务正文含 U+2028 等特殊换行符时，账本会被判为不可解析），本项目尚未同步，不在本任务范围。日后同步模板时，按“与模板的差异”重放本次三处改动。
- 守护测试里“被拒绝的事件不改动任务”，覆盖的是旧格式规则与交付、通过前置检查里的拒绝。超出窗口容量的拒绝发生在任务表更新之后，新旧代码一样；任何拒绝都会让整次重放作废，命令看不到中间状态。
- 每条命令仍重放 3 遍（写一笔约 8 遍），单遍约 0.07 秒，耗时现在随账本长度线性增长。提交检查剩下的约 5 秒主要花在逐个文件调用 `git cat-file`，本任务未动。
- 另一个克隆须先拉取本次提交再写账。新旧工具写出的记录完全相同，只是旧工具仍慢。
- 对照脚本、两个临时克隆与日志都在会话临时目录，不入库。
