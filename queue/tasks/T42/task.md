# 补写 iOS 测试筛选说明：检查清单与开发环境说明

```json
{
  "id": "T42",
  "revision": 726,
  "assignee": null,
  "parent": null,
  "deps": [
    "T38",
    "T41"
  ],
  "round": 1,
  "status": "通过"
}
```

## 登记依据

用户决定把任务 [T41](../T41/goal.md) 原方案里的两处说明拆出来单独做：`gate/checks.md` 与 `object/dev/README.md` 是任务 [T38](../T38/goal.md) 本轮的交付文件，T38 通过前改动它们，T38 就不能直接通过。T41 在 `object/dev/ios-check.sh` 新增可选环境变量 `SAFEORBIT_ONLY_TESTING`（只跑所列测试类），用法暂时写在脚本注释里；本件在 T38、T41 都通过后，把说明补进这两份文件。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000725.md](receipt-000725.md)

## 过程记录

- #696｜create｜Claude Code｜{"authority": {"basis": "用户明确指令：另登记并批准一件任务，承接 gate/checks.md 与 object/dev/README.md 的说明，等 T38 通过后再做。", "by": "用户"}, "deps": ["T38", "T41"], "id": "T42", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 说明写齐 | 阅读两处差异；`grep -rn SAFEORBIT_ONLY_TESTING` 核对出现位置 | gate 写明标识写法（类名而非文件名）、没有匹配到测试即报错、读数以全套为准，与脚本注释一致；README 补了一句并指向 gate；其他章节不变 |\n| A2 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T38、T41 的状态；提交时的队列检查 | 仅上述两处；领取前 T38、T41 已通过；退出码 0 |\n\n验收安排：执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”；只改说明文字，不重跑 iOS 测试。最终由用户验收。", "origin": "用户决定把任务 [T41](../T41/goal.md) 原方案里的两处说明拆出来单独做：`gate/checks.md` 与 `object/dev/README.md` 是任务 [T38](../T38/goal.md) 本轮的交付文件，T38 通过前改动它们，T38 就不能直接通过。T41 在 `object/dev/ios-check.sh` 新增可选环境变量 `SAFEORBIT_ONLY_TESTING`（只跑所列测试类），用法暂时写在脚本注释里；本件在 T38、T41 都通过后，把说明补进这两份文件。", "plan": "1. 写账前比对远端；T38、T41 都通过后领取。\n2. 按 T41 交付的脚本注释补写两处说明。\n3. 跑 A1、A2；写回执交付，同批提交并推送；等用户验收。", "scope": "- 要交付：\n  - `gate/checks.md` 的“iOS 构建与单元测试”一节：补写 `SAFEORBIT_ONLY_TESTING`——标识写成 `SafeOrbitTests/<测试类名>` 或 `SafeOrbitTests/<测试类名>/<方法名>`，填的是测试类名而不是文件名（以 `RecordsTests.swift` 里的几个测试类为例）；所列某一项没有匹配到测试时脚本报错；写明任务回执与验收的读数一律以全套为准。内容与 T41 交付的脚本注释一致。\n  - `object/dev/README.md` 的“验证”一节：在介绍 `SAFEORBIT_SIMULATOR_ID` 的那句之后补一句：只跑部分测试类时设 `SAFEORBIT_ONLY_TESTING`，写法与“读数以全套为准”见 `gate/checks.md`。\n- 不包含：`object/dev/ios-check.sh` 与根契约（属 T41）；两份文件的其他章节；其他文件。\n- 允许修改的位置：`gate/checks.md`（仅“iOS 构建与单元测试”一节）；`object/dev/README.md`（仅“验证”一节补一句）。队列记录只经工具维护。", "title": "补写 iOS 测试筛选说明：检查清单与开发环境说明"}}
- #724｜claim｜Codex｜{"expect": 696, "id": "T42"}
- #725｜deliver｜Codex｜{"artifacts": [{"path": "gate/checks.md", "sha256": "b6d789f81ff36e1046f07227eeed547c86240ab38e6700a962ab7d9b121ecff0"}, {"path": "object/dev/README.md", "sha256": "06687fe9fd3880fa3c2164e329d517b3e6442b0fcd544848858ab27d6ea2202b"}], "expect": 724, "id": "T42", "receipt": "# T42 交付回执\n\n## 交付内容\n\n- gate/checks.md 仅在“iOS 构建与单元测试”一节新增部分测试说明：SAFEORBIT_ONLY_TESTING 的类与方法标识、逗号分隔示例、RecordsTests.swift 内的四个测试类、任一项没有实际执行测试即报错，以及交付与验收读数一律以取消该变量后的全套为准。\n- object/dev/README.md 仅在“验证”一节的 SAFEORBIT_SIMULATOR_ID 提示后补一句，并链接检查清单的对应章节。\n- 未修改脚本、App、测试或依赖。开始时已有 Localizable.xcstrings 与 SafeOrbit.entitlements 的未提交改动，未纳入本任务暂存。验证由执行者完成，未独立验证。\n\n## 验证读数\n\n1. `sh object/dev/queue.sh doctor`：退出码 0，原样输出 `{\"ok\": true, \"protection\": \"ready\", \"seq\": 723, \"tasks\": 43, \"protocol\": 2}`。\n2. `git fetch origin`：在环境授权后退出码 0，无输出；按 tool/queue-usage.md 的前缀比较脚本核对机器账，退出码 0，原样输出 `一致：远端账是本地账的前缀，可以继续写账和推送。`。\n3. `sh object/dev/queue.sh task status`（筛选 T38、T41、T42）：退出码 0，领取前 T38 为通过、revision 702，T41 为通过、revision 701，T42 为批准且 ready=true、revision 696。\n4. `grep -rn SAFEORBIT_ONLY_TESTING gate/checks.md object/dev/README.md object/dev/ios-check.sh`：退出码 0，命中 gate/checks.md:58、object/dev/README.md:123 及脚本的注释、筛选和报错位置；人工逐项对照，内容一致。`rg -n 'class .*Tests|struct .*Tests|func testRiskHomeSnapshots' object/ios/SafeOrbitTests/RecordsTests.swift object/ios/SafeOrbitTests/LocationTests.swift`：退出码 0，确认 RecordsTests、ElderFrontendTests、ElderLiveNavigationTests、AgentSessionTests 与方法 testRiskHomeSnapshots 存在。\n5. `git diff -- gate/checks.md object/dev/README.md`：退出码 0，gate 只增加一行，README 只在原段落增加一句。`python3 -` 内断言两份文档授权章节以外的内容保持一致、资源键出现次数与 README 链接目标存在：退出码 0，原样输出摘录 `PASS: only the approved iOS-check section and README verification section changed; README target exists.`。\n6. `git diff --check`：退出码 0，无输出。\n7. `sh object/dev/queue.sh check --staged`：暂存本件两份文档与领取记录后退出码 0，原样输出 `{\"ok\": true, \"checked\": \"staged\", \"seq\": 724}`。交付回执加入后由正常提交钩子再次检查。\n\n## 收尾与限制\n\n本件仅补说明，按批准基线不重跑 iOS 测试；没有将文档核对表述为新一轮 iOS 测试通过。交付记录与两份文档同批提交并推送，最终结果以本轮工具输出与汇报为准，不在此预报。任务保留交付状态，等待用户验收，未自行记通过。\n", "summary": "两处 iOS 测试筛选说明已补齐，与脚本和测试类名一致；差异与暂存检查通过，未独立验证。", "verification": "passed"}
- #726｜close｜Codex｜{"authority": {"basis": "用户明确确认验收检查通过后直接登记通过。另一独立执行实例已按批准基线核对两处说明、改动范围和交付文件，两项验收标准均通过。本轮复核两份文档仍与交付时一致。", "by": "用户"}, "expect": 725, "id": "T42"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
