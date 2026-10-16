# T23 交付回执

新增只用标准库的并行运行脚本 `gate/run_parallel.py`，并同步命令表、检查清单、工具清单与“与模板的差异”表；原来的顺序命令保留不变。改动与验证都由执行者完成，没有派子代理。验证未独立验证，尚未由用户验收。

## 实际修改

- `gate/run_parallel.py`（新增）：用 unittest 发现 gate 下的 `test_*.py`，每项测试在独立进程中以 `python -B -m unittest <测试名>` 运行，工作目录为 gate（与 `discover -s gate` 的导入路径一致）；`-j N` 指定同时运行的测试数，默认取本机核心数；可只跑指定的测试名。汇总时先列出失败项的原样输出，末尾输出 `Ran N tests in X s with J jobs` 与 `OK` 或 `FAILED (failures=k)`；全部通过退出码 0，有失败、测试发现出错或没有找到测试时退出码 1，`-j` 不是正整数时由参数解析拒绝（退出码 2）。按发现顺序调度，不依赖历史耗时数据。
- 根 `AGENTS.md` 第 5 节命令表“队列工具测试”一行：补上并行命令，说明顺序约 3 分钟、并行约半分钟。
- `gate/checks.md`“默认队列检查”：在顺序命令后补并行命令、`-j` 用法与本机读数，注明并行时 `QUEUE_TEST_LOG` 转录行可能交错。
- `tool/catalog.md` 队列工具“验证”一行：补上并行运行脚本的链接。
- `tool/AGENTS.md`“与模板的差异”表：新增 `gate/run_parallel.py` 一行，任务 T23。
- 没有修改任何现有测试与队列工具；没有新增依赖。

## 验证

A1 并行跑（主工作树）：

```sh
/opt/anaconda3/bin/python3 -B gate/run_parallel.py
/opt/anaconda3/bin/python3 -B gate/run_parallel.py -j 8
```

默认一次、`-j 8` 三次，退出码都是 0，原样结尾：

```text
Ran 103 tests in 23.434s with 14 jobs
OK
Ran 103 tests in 30.832s with 8 jobs
OK
Ran 103 tests in 30.625s with 8 jobs
OK
Ran 103 tests in 31.018s with 8 jobs
OK
```

临时克隆中的试跑读数一致（默认 24.044 秒；`-j 8` 三次 30.738、31.003、30.827 秒，全部 OK）。

A2 顺序命令照旧可用（主工作树）：

```sh
/opt/anaconda3/bin/python3 -B -m unittest discover -s gate -p 'test_*.py'
```

退出码 0，原样结尾 `Ran 103 tests in 188.211s` 与 `OK`。顺序 188.2 秒对比并行默认 23.4 秒，约快 8 倍；`-j 8` 约快 6 倍。

A3 失败如实报告：在会话临时目录放脚本副本与一个测试文件（一项必然通过、一项断言 `'实际' != '期望'` 必然失败），运行 `run_parallel.py -j 2`：退出码 1，输出先列 `FAIL test_demo.Demo.test_fails_on_purpose` 及其原样 traceback，末尾 `Ran 2 tests in 0.029s with 2 jobs`、`FAILED (failures=1)`。另核对：只跑指定的通过项，退出码 0、`Ran 1 tests`；指定不存在的测试名，退出码 1、`FAILED (failures=1)`；放一个导入失败的测试文件，输出“测试发现失败”与原样 traceback，退出码 1；`-j 0` 被参数解析拒绝，退出码 2。

A4 只用标准库：脚本的 import 为 `__future__`、`argparse`、`concurrent.futures`、`os`、`pathlib`、`subprocess`、`sys`、`time`、`unittest`，全部是标准库。

A5 文档一致：

```sh
git grep -n 'run_parallel'
git grep -n 'unittest discover'
```

并行命令出现在根 `AGENTS.md` 命令表、`gate/checks.md`、`tool/catalog.md` 与 `tool/AGENTS.md` 差异表，写法一致；顺序命令仍在根 `AGENTS.md`、`gate/checks.md` 与 `gate/test_task_queue.py` 文件头。`CHANGELOG.md` 是模板的变更记录，未改。

A6：

```sh
git diff --check
git diff --stat
```

前者退出码 0、输出为空；后者原样为 4 个已跟踪文件（`AGENTS.md`、`gate/checks.md`、`tool/AGENTS.md`、`tool/catalog.md`），4 行新增、3 行删除，另加新文件 `gate/run_parallel.py`。提交时的队列检查在本次交付提交中运行。

## 说明

- 并行的下限是最慢的单项测试（约 6.7 秒）。脚本按发现顺序调度；评估时按“最慢优先”排序可再快约 4 秒（默认路数约 20 秒），但需要保存历史耗时，没有采用。
- 文档中的耗时是本机（14 核）读数，换机器会不同。
- 提交钩子仍不跑这套测试，本任务未改变这一点。
- 范围外的发现：任务 T23 在 T22 交付期间显示的阻塞原因是“前置 T22 为批准，未通过”，而 T22 当时处于“交付”。这是队列工具把新状态映射回旧状态名时的原有措辞，T22 改动前后一样，未在本任务处理。
