# 补写 iOS 测试筛选说明：检查清单与开发环境说明

```json
{
  "id": "T42",
  "revision": 696,
  "assignee": null,
  "parent": null,
  "deps": [
    "T38",
    "T41"
  ],
  "round": 1,
  "status": "批准"
}
```

## 登记依据

用户决定把任务 [T41](../T41/goal.md) 原方案里的两处说明拆出来单独做：`gate/checks.md` 与 `object/dev/README.md` 是任务 [T38](../T38/goal.md) 本轮的交付文件，T38 通过前改动它们，T38 就不能直接通过。T41 在 `object/dev/ios-check.sh` 新增可选环境变量 `SAFEORBIT_ONLY_TESTING`（只跑所列测试类），用法暂时写在脚本注释里；本件在 T38、T41 都通过后，把说明补进这两份文件。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)

## 过程记录

- #696｜create｜Claude Code｜{"authority": {"basis": "用户明确指令：另登记并批准一件任务，承接 gate/checks.md 与 object/dev/README.md 的说明，等 T38 通过后再做。", "by": "用户"}, "deps": ["T38", "T41"], "id": "T42", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 说明写齐 | 阅读两处差异；`grep -rn SAFEORBIT_ONLY_TESTING` 核对出现位置 | gate 写明标识写法（类名而非文件名）、没有匹配到测试即报错、读数以全套为准，与脚本注释一致；README 补了一句并指向 gate；其他章节不变 |\n| A2 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T38、T41 的状态；提交时的队列检查 | 仅上述两处；领取前 T38、T41 已通过；退出码 0 |\n\n验收安排：执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”；只改说明文字，不重跑 iOS 测试。最终由用户验收。", "origin": "用户决定把任务 [T41](../T41/goal.md) 原方案里的两处说明拆出来单独做：`gate/checks.md` 与 `object/dev/README.md` 是任务 [T38](../T38/goal.md) 本轮的交付文件，T38 通过前改动它们，T38 就不能直接通过。T41 在 `object/dev/ios-check.sh` 新增可选环境变量 `SAFEORBIT_ONLY_TESTING`（只跑所列测试类），用法暂时写在脚本注释里；本件在 T38、T41 都通过后，把说明补进这两份文件。", "plan": "1. 写账前比对远端；T38、T41 都通过后领取。\n2. 按 T41 交付的脚本注释补写两处说明。\n3. 跑 A1、A2；写回执交付，同批提交并推送；等用户验收。", "scope": "- 要交付：\n  - `gate/checks.md` 的“iOS 构建与单元测试”一节：补写 `SAFEORBIT_ONLY_TESTING`——标识写成 `SafeOrbitTests/<测试类名>` 或 `SafeOrbitTests/<测试类名>/<方法名>`，填的是测试类名而不是文件名（以 `RecordsTests.swift` 里的几个测试类为例）；所列某一项没有匹配到测试时脚本报错；写明任务回执与验收的读数一律以全套为准。内容与 T41 交付的脚本注释一致。\n  - `object/dev/README.md` 的“验证”一节：在介绍 `SAFEORBIT_SIMULATOR_ID` 的那句之后补一句：只跑部分测试类时设 `SAFEORBIT_ONLY_TESTING`，写法与“读数以全套为准”见 `gate/checks.md`。\n- 不包含：`object/dev/ios-check.sh` 与根契约（属 T41）；两份文件的其他章节；其他文件。\n- 允许修改的位置：`gate/checks.md`（仅“iOS 构建与单元测试”一节）；`object/dev/README.md`（仅“验证”一节补一句）。队列记录只经工具维护。", "title": "补写 iOS 测试筛选说明：检查清单与开发环境说明"}}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
