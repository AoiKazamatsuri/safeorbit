# 队列工具测试并行运行脚本

## 范围

- 要交付：
  - 新增 `gate/run_parallel.py`：只用 Python 标准库；用 unittest 发现 gate 下的 `test_*.py`，每项测试在独立进程中运行，按 `-j N` 同时跑（默认取本机核心数），可选只跑指定的测试名；汇总时列出失败项的原样输出，末尾给出“Ran N tests in X s”与 OK 或 FAILED，全部通过时退出码 0，否则 1。
  - `gate/checks.md`“默认队列检查”：在顺序命令旁加并行命令与读数说明。
  - 根 `AGENTS.md` 第 5 节命令表：队列工具测试一行补上并行命令。
  - `tool/catalog.md` 队列工具的“验证”一行：补上并行运行脚本。
  - `tool/AGENTS.md`“与模板的差异”表：登记新增的 `gate/run_parallel.py`。
- 不包含：修改任何现有测试与队列工具；第三方测试框架（如 pytest-xdist）；把测试接进提交钩子；`CHANGELOG.md`；`object/` 下任何文件。
- 允许修改的位置：`gate/run_parallel.py`（新增）、`gate/checks.md`、`AGENTS.md`（仅命令表一行）、`tool/catalog.md`（仅队列工具验证一行）、`tool/AGENTS.md`（仅差异表）。队列记录只经工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 并行跑全部通过且明显更快 | 主工作树运行 `/opt/anaconda3/bin/python3 -B gate/run_parallel.py`，并以 `-j 8` 各跑至少 3 次 | 每次 103 项全部通过、退出码 0；默认路数下 60 秒以内 |
| A2 | 顺序命令照旧可用 | `/opt/anaconda3/bin/python3 -B -m unittest discover -s gate -p 'test_*.py'` | 退出码 0、103 项 OK |
| A3 | 失败能被如实报告 | 在临时副本里放一个必然失败的测试再跑并行脚本 | 退出码 1，列出该失败项及其原样输出，其他测试照常汇总 |
| A4 | 只用标准库 | 阅读脚本的 import | 只有标准库模块 |
| A5 | 文档与脚本一致 | `git grep -n 'run_parallel'` 与 `git grep -n 'unittest discover'` | 命令表、检查清单、工具清单写法一致，顺序命令仍在 |
| A6 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；提交时的队列检查 | 仅授权文件；检查退出码 0 |

验收安排：A1–A6 由执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”；用户验收。
