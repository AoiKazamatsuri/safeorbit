# 移除 Recording 趋势页底部出行规律说明卡

```json
{
  "id": "T45",
  "revision": 737,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "通过"
}
```

## 登记依据

用户提供 Recording 页的截图，明确要求删除底部显示出行规律的文字卡。此项调整更新任务 T39 之后的趋势页展示要求。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000733.md](receipt-000733.md)

## 过程记录

- #731｜create｜Codex｜{"authority": {"basis": "用户明确要求删除截图中 Recording 页底部的出行规律说明栏。", "by": "用户"}, "deps": [], "id": "T45", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | Trend 页保留折线图和四张指标卡，末尾没有规律说明卡 | 在 iPhone 18 Pro 模拟器打开已有记录的月份并滚动到 Trend 页底部 | 图表和指标仍可见，底部没有说明卡 |\n| A2 | Recording 页面与 App 其他既有行为通过检查 | sh object/dev/ios-check.sh 全套 | 退出码 0 |\n| A3 | 图纸一致，提交只包括本次改动 | 运行架构图纸检查、git diff --check 与队列暂存检查 | 退出码均为 0，提交包含本任务记录与指定工件 |\n\n验收安排：执行者本机代跑并记录输出，标注未独立验证。用户决定是否验收通过。", "origin": "用户提供 Recording 页的截图，明确要求删除底部显示出行规律的文字卡。此项调整更新任务 T39 之后的趋势页展示要求。", "plan": "1. 删除趋势页的文字卡视图并同步有关文档。\n2. 运行全套 iOS 测试和架构图纸检查，用既有本机数据验证界面。\n3. 登记交付，随工件提交并推送。", "scope": "- 要交付：移除家属端 Recording 的 Trend 页在指标卡下方显示的出行规律文字卡。同步项目目标、产品设计及架构说明中的展示描述。\n- 不包含：调整图表、指标、Data 页、后端统计、趋势接口、现有历史数据与架构图。\n- 允许修改的位置：object/ios/SafeOrbit/RecordsUI.swift；truth/goals.md、truth/产品设计.md、truth/工程架构.md、truth/architecture/safeorbit-care-agent/safeorbit-care-agent.md 中与此卡展示相关的文字。队列记录经工具维护。", "title": "移除 Recording 趋势页底部出行规律说明卡"}}
- #732｜claim｜Codex｜{"expect": 731, "id": "T45"}
- #733｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/RecordsUI.swift", "sha256": "539d069786afa2f1f8fd509f61725aa561b733d911083583f675c618c77bde41"}, {"path": "truth/goals.md", "sha256": "a3444efa869b3d001c7ef373c3e1fa92b479db5454429371afe283caeb808cc1"}, {"path": "truth/产品设计.md", "sha256": "39fc309dad252261fa0cd5afb1f25049cfe60fde7f2704bd856861d5120af9a8"}, {"path": "truth/工程架构.md", "sha256": "f33a72d448df37182b206800ac3d8cc07346c7d1ce8e1d68bef719449d3b7c01"}, {"path": "truth/architecture/safeorbit-care-agent/safeorbit-care-agent.md", "sha256": "dc135d9851cdef041e97da9e5c7d8074dc48c19a8fefa956cdae4845582d5946"}], "expect": 732, "id": "T45", "receipt": "# T45 交付回执\n\n已删除家属端 Recording 的 Trend 页最下方的出行规律文字卡。同步项目目标、产品设计和架构说明中的展示描述。趋势统计与出行记录继续使用现有后端。以下均为执行者本机核对，未独立验证。\n\n- 模拟器实跑：用 `xcrun simctl install \"$sim\" \"$app\"` 安装此次构建的 App，再用 `xcrun simctl launch --terminate-running-process \"$sim\" org.safeorbit.demo` 启动，退出码 0，原样输出 `org.safeorbit.demo: 9909`。其中 sim 是 iPhone 18 Pro 的编号，app 是本轮构建的 SafeOrbit.app。进入家属端 Recording，Data 显示 2026 年 10 月月历与 10 月 26–28 日三条记录。切到 Trend 后看到折线图及四张指标卡。滚到末尾，最后一排是高风险和安全返回率指标，说明卡已移除。\n- 在 iPhone 17e 上以 `SAFEORBIT_SIMULATOR_ID=3BB99185-DE9E-4BB4-9008-362655244B57 sh object/dev/ios-check.sh` 运行全套，未设置筛选变量。原样摘录 `Executed 168 tests, with 0 failures (0 unexpected) in 610.553 (610.615) seconds` 和 `** TEST SUCCEEDED **`。外层 zsh 包装在测试结束后因使用只读变量返回 1，未单独捕获测试脚本退出码。随后运行 `xcrun xcresulttool get test-results summary --path 'object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.11.08_17-39-06-+0800.xcresult'`，退出码 0，原样摘录 `\"failedTests\" : 0`、`\"passedTests\" : 168`、`\"result\" : \"Passed\"`、`\"skippedTests\" : 0`。\n- `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出码 0，原样输出 `无红。`。`git diff --check` 和 `git diff --cached --check` 均退出 0，输出为空。\n- `/Users/idesign/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tool/shell.py check --staged` 退出码 0，原样输出 `{\"ok\": true, \"checked\": \"staged\", \"seq\": 732}`。已核对暂存范围。交付回执加入暂存区后再运行一次检查和提交钩子。\n", "summary": "删除趋势页底部说明卡，模拟器实跑及 168 项 iOS 测试通过，未独立验证。", "verification": "passed"}
- #737｜close｜Codex｜{"authority": {"basis": "用户指示验收 T45。独立验收核对交付五份文件、趋势页与文档差异，复核模拟器记录和 Xcode 结果包，168 项测试通过、零失败，符合批准范围。", "by": "用户"}, "expect": 733, "id": "T45"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
