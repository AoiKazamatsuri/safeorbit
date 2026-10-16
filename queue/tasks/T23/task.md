# 队列工具测试并行运行脚本

```json
{
  "id": "T23",
  "revision": 617,
  "assignee": null,
  "parent": null,
  "deps": [
    "T22"
  ],
  "round": 1,
  "status": "通过"
}
```

## 登记依据

T22 交付后评估队列工具测试（gate 下 103 项）能否并行提速：每项测试都在自己的临时 Git 仓库里运行，只读取项目工具文件，彼此不共享可写状态；顺序跑时 CPU 只用到约 71%，主要在等 git 与写盘。在会话临时目录用标准库脚本试跑（每项一个进程、多项同时跑）：顺序 194.6 秒；4 路 51.0 秒；8 路 27.1–28.0 秒；14 路 20.2–21.7 秒；8 路与 14 路各重复 4 次、4 路 1 次，全部 103 项通过，没有偶发失败。最慢单项 6.7 秒，是并行的下限。

用户明确指令：同意登记任务，在 gate 加只用标准库的并行运行脚本，同步命令表、检查清单与“与模板的差异”表，原来的顺序命令保留。

本任务依赖 T22：`tool/AGENTS.md` 是 T22 的交付工件，T22 通过之前改它会使 T22 的工件指纹失效，所以 T22 通过后才领取施工。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000616.md](receipt-000616.md)

## 过程记录

- #613｜create｜Claude Code｜{"authority": {"basis": "用户明确指令：同意登记任务，在 gate 加只用标准库的并行运行脚本，同步命令表、检查清单与差异表，原来的顺序命令保留。", "by": "用户"}, "deps": ["T22"], "id": "T23", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 并行跑全部通过且明显更快 | 主工作树运行 `/opt/anaconda3/bin/python3 -B gate/run_parallel.py`，并以 `-j 8` 各跑至少 3 次 | 每次 103 项全部通过、退出码 0；默认路数下 60 秒以内 |\n| A2 | 顺序命令照旧可用 | `/opt/anaconda3/bin/python3 -B -m unittest discover -s gate -p 'test_*.py'` | 退出码 0、103 项 OK |\n| A3 | 失败能被如实报告 | 在临时副本里放一个必然失败的测试再跑并行脚本 | 退出码 1，列出该失败项及其原样输出，其他测试照常汇总 |\n| A4 | 只用标准库 | 阅读脚本的 import | 只有标准库模块 |\n| A5 | 文档与脚本一致 | `git grep -n 'run_parallel'` 与 `git grep -n 'unittest discover'` | 命令表、检查清单、工具清单写法一致，顺序命令仍在 |\n| A6 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；提交时的队列检查 | 仅授权文件；检查退出码 0 |\n\n验收安排：A1–A6 由执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”；用户验收。", "origin": "T22 交付后评估队列工具测试（gate 下 103 项）能否并行提速：每项测试都在自己的临时 Git 仓库里运行，只读取项目工具文件，彼此不共享可写状态；顺序跑时 CPU 只用到约 71%，主要在等 git 与写盘。在会话临时目录用标准库脚本试跑（每项一个进程、多项同时跑）：顺序 194.6 秒；4 路 51.0 秒；8 路 27.1–28.0 秒；14 路 20.2–21.7 秒；8 路与 14 路各重复 4 次、4 路 1 次，全部 103 项通过，没有偶发失败。最慢单项 6.7 秒，是并行的下限。\n\n用户明确指令：同意登记任务，在 gate 加只用标准库的并行运行脚本，同步命令表、检查清单与“与模板的差异”表，原来的顺序命令保留。\n\n本任务依赖 T22：`tool/AGENTS.md` 是 T22 的交付工件，T22 通过之前改它会使 T22 的工件指纹失效，所以 T22 通过后才领取施工。", "plan": "1. 写账前比对远端，登记并批准（依赖 T22），同批提交并推送。\n2. 在临时克隆中写脚本与文档改动，跑 A1–A4。\n3. T22 通过后领取，合入主工作树，跑 A1–A6；写回执交付，同批提交并推送。", "scope": "- 要交付：\n  - 新增 `gate/run_parallel.py`：只用 Python 标准库；用 unittest 发现 gate 下的 `test_*.py`，每项测试在独立进程中运行，按 `-j N` 同时跑（默认取本机核心数），可选只跑指定的测试名；汇总时列出失败项的原样输出，末尾给出“Ran N tests in X s”与 OK 或 FAILED，全部通过时退出码 0，否则 1。\n  - `gate/checks.md`“默认队列检查”：在顺序命令旁加并行命令与读数说明。\n  - 根 `AGENTS.md` 第 5 节命令表：队列工具测试一行补上并行命令。\n  - `tool/catalog.md` 队列工具的“验证”一行：补上并行运行脚本。\n  - `tool/AGENTS.md`“与模板的差异”表：登记新增的 `gate/run_parallel.py`。\n- 不包含：修改任何现有测试与队列工具；第三方测试框架（如 pytest-xdist）；把测试接进提交钩子；`CHANGELOG.md`；`object/` 下任何文件。\n- 允许修改的位置：`gate/run_parallel.py`（新增）、`gate/checks.md`、`AGENTS.md`（仅命令表一行）、`tool/catalog.md`（仅队列工具验证一行）、`tool/AGENTS.md`（仅差异表）。队列记录只经工具维护。", "title": "队列工具测试并行运行脚本"}}
- #615｜claim｜Claude Code｜{"expect": 613, "id": "T23"}
- #616｜deliver｜Claude Code｜{"artifacts": [{"path": "gate/run_parallel.py", "sha256": "64a05920498baa6893bd5f5bfa700f18ff4e4e4358e1d879da6423e215ae5ef1"}, {"path": "AGENTS.md", "sha256": "dfacac4549e0ba8d13f1028ecc7b375db979111c7a2d3cb4805cdba36c93a151"}, {"path": "gate/checks.md", "sha256": "00dc713b30db0d53b0430ae482f2169b1e395bbe7145f14ecf83344c1fc7dc17"}, {"path": "tool/catalog.md", "sha256": "f8dd7d1768cfd2f40f4c13789db4cd1afce5080542943fa0c73e9d89c7eadeba"}, {"path": "tool/AGENTS.md", "sha256": "aac00c9a961559e16612472b756507b10e61d9477a90117f8cc6e36337d9e95d"}], "expect": 615, "id": "T23", "receipt": "# T23 交付回执\n\n新增只用标准库的并行运行脚本 `gate/run_parallel.py`，并同步命令表、检查清单、工具清单与“与模板的差异”表；原来的顺序命令保留不变。改动与验证都由执行者完成，没有派子代理。验证未独立验证，尚未由用户验收。\n\n## 实际修改\n\n- `gate/run_parallel.py`（新增）：用 unittest 发现 gate 下的 `test_*.py`，每项测试在独立进程中以 `python -B -m unittest <测试名>` 运行，工作目录为 gate（与 `discover -s gate` 的导入路径一致）；`-j N` 指定同时运行的测试数，默认取本机核心数；可只跑指定的测试名。汇总时先列出失败项的原样输出，末尾输出 `Ran N tests in X s with J jobs` 与 `OK` 或 `FAILED (failures=k)`；全部通过退出码 0，有失败、测试发现出错或没有找到测试时退出码 1，`-j` 不是正整数时由参数解析拒绝（退出码 2）。按发现顺序调度，不依赖历史耗时数据。\n- 根 `AGENTS.md` 第 5 节命令表“队列工具测试”一行：补上并行命令，说明顺序约 3 分钟、并行约半分钟。\n- `gate/checks.md`“默认队列检查”：在顺序命令后补并行命令、`-j` 用法与本机读数，注明并行时 `QUEUE_TEST_LOG` 转录行可能交错。\n- `tool/catalog.md` 队列工具“验证”一行：补上并行运行脚本的链接。\n- `tool/AGENTS.md`“与模板的差异”表：新增 `gate/run_parallel.py` 一行，任务 T23。\n- 没有修改任何现有测试与队列工具；没有新增依赖。\n\n## 验证\n\nA1 并行跑（主工作树）：\n\n```sh\n/opt/anaconda3/bin/python3 -B gate/run_parallel.py\n/opt/anaconda3/bin/python3 -B gate/run_parallel.py -j 8\n```\n\n默认一次、`-j 8` 三次，退出码都是 0，原样结尾：\n\n```text\nRan 103 tests in 23.434s with 14 jobs\nOK\nRan 103 tests in 30.832s with 8 jobs\nOK\nRan 103 tests in 30.625s with 8 jobs\nOK\nRan 103 tests in 31.018s with 8 jobs\nOK\n```\n\n临时克隆中的试跑读数一致（默认 24.044 秒；`-j 8` 三次 30.738、31.003、30.827 秒，全部 OK）。\n\nA2 顺序命令照旧可用（主工作树）：\n\n```sh\n/opt/anaconda3/bin/python3 -B -m unittest discover -s gate -p 'test_*.py'\n```\n\n退出码 0，原样结尾 `Ran 103 tests in 188.211s` 与 `OK`。顺序 188.2 秒对比并行默认 23.4 秒，约快 8 倍；`-j 8` 约快 6 倍。\n\nA3 失败如实报告：在会话临时目录放脚本副本与一个测试文件（一项必然通过、一项断言 `'实际' != '期望'` 必然失败），运行 `run_parallel.py -j 2`：退出码 1，输出先列 `FAIL test_demo.Demo.test_fails_on_purpose` 及其原样 traceback，末尾 `Ran 2 tests in 0.029s with 2 jobs`、`FAILED (failures=1)`。另核对：只跑指定的通过项，退出码 0、`Ran 1 tests`；指定不存在的测试名，退出码 1、`FAILED (failures=1)`；放一个导入失败的测试文件，输出“测试发现失败”与原样 traceback，退出码 1；`-j 0` 被参数解析拒绝，退出码 2。\n\nA4 只用标准库：脚本的 import 为 `__future__`、`argparse`、`concurrent.futures`、`os`、`pathlib`、`subprocess`、`sys`、`time`、`unittest`，全部是标准库。\n\nA5 文档一致：\n\n```sh\ngit grep -n 'run_parallel'\ngit grep -n 'unittest discover'\n```\n\n并行命令出现在根 `AGENTS.md` 命令表、`gate/checks.md`、`tool/catalog.md` 与 `tool/AGENTS.md` 差异表，写法一致；顺序命令仍在根 `AGENTS.md`、`gate/checks.md` 与 `gate/test_task_queue.py` 文件头。`CHANGELOG.md` 是模板的变更记录，未改。\n\nA6：\n\n```sh\ngit diff --check\ngit diff --stat\n```\n\n前者退出码 0、输出为空；后者原样为 4 个已跟踪文件（`AGENTS.md`、`gate/checks.md`、`tool/AGENTS.md`、`tool/catalog.md`），4 行新增、3 行删除，另加新文件 `gate/run_parallel.py`。提交时的队列检查在本次交付提交中运行。\n\n## 说明\n\n- 并行的下限是最慢的单项测试（约 6.7 秒）。脚本按发现顺序调度；评估时按“最慢优先”排序可再快约 4 秒（默认路数约 20 秒），但需要保存历史耗时，没有采用。\n- 文档中的耗时是本机（14 核）读数，换机器会不同。\n- 提交钩子仍不跑这套测试，本任务未改变这一点。\n- 范围外的发现：任务 T23 在 T22 交付期间显示的阻塞原因是“前置 T22 为批准，未通过”，而 T22 当时处于“交付”。这是队列工具把新状态映射回旧状态名时的原有措辞，T22 改动前后一样，未在本任务处理。\n", "summary": "新增标准库并行运行脚本 gate/run_parallel.py，同步命令表、检查清单、工具清单与差异表；103 项测试并行默认 23.4 秒、-j 8 约 31 秒（顺序 188.2 秒），全部通过，失败能如实报告；未独立验证。", "verification": "passed"}
- #617｜close｜Claude Code｜{"authority": {"basis": "用户明确指令：验收通过 T23（测试并行运行脚本），记为通过。", "by": "用户"}, "expect": 616, "id": "T23"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
