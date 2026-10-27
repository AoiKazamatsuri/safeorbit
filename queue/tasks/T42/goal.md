# 补写 iOS 测试筛选说明：检查清单与开发环境说明

## 范围

- 要交付：
  - `gate/checks.md` 的“iOS 构建与单元测试”一节：补写 `SAFEORBIT_ONLY_TESTING`——标识写成 `SafeOrbitTests/<测试类名>` 或 `SafeOrbitTests/<测试类名>/<方法名>`，填的是测试类名而不是文件名（以 `RecordsTests.swift` 里的几个测试类为例）；所列某一项没有匹配到测试时脚本报错；写明任务回执与验收的读数一律以全套为准。内容与 T41 交付的脚本注释一致。
  - `object/dev/README.md` 的“验证”一节：在介绍 `SAFEORBIT_SIMULATOR_ID` 的那句之后补一句：只跑部分测试类时设 `SAFEORBIT_ONLY_TESTING`，写法与“读数以全套为准”见 `gate/checks.md`。
- 不包含：`object/dev/ios-check.sh` 与根契约（属 T41）；两份文件的其他章节；其他文件。
- 允许修改的位置：`gate/checks.md`（仅“iOS 构建与单元测试”一节）；`object/dev/README.md`（仅“验证”一节补一句）。队列记录只经工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 说明写齐 | 阅读两处差异；`grep -rn SAFEORBIT_ONLY_TESTING` 核对出现位置 | gate 写明标识写法（类名而非文件名）、没有匹配到测试即报错、读数以全套为准，与脚本注释一致；README 补了一句并指向 gate；其他章节不变 |
| A2 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T38、T41 的状态；提交时的队列检查 | 仅上述两处；领取前 T38、T41 已通过；退出码 0 |

验收安排：执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”；只改说明文字，不重跑 iOS 测试。最终由用户验收。
