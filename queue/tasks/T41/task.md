# 施工提速：iOS 测试分两档，前后端按接口约定并行

```json
{
  "id": "T41",
  "revision": 694,
  "assignee": null,
  "parent": null,
  "deps": [
    "T38"
  ],
  "round": 1,
  "status": "批准"
}
```

## 登记依据

用户在任务 [T38](../T38/goal.md) 施工后要求落实两条提速做法，并同意先登记、看过方案再批准。T38 的实况（执行者记录，未独立验证）：

- iOS 全套测试每遍约 10 分钟（150 余个用例，其中大量截图与布局用例要在六种屏宽、多档字号下渲染），施工中改了再测，至少跑了 3 遍。
- App 端要按后端实际定下的接口写，只能等后端交回、执行者审阅提交后才开工；后端约 38 分钟、App 端约 65 分钟，基本串行。

目的：施工中途只跑受影响的测试类，交付前跑一次全套；同时改后端与 App 的任务，先写定接口约定，让两边的子代理同时开工。

修订（登记后、批准前，用户看过执行者的只读摸底后决定）：补三处——写明测试标识填的是测试类名而不是文件名；所列测试标识没有匹配到测试时脚本报错，防止拼错时假通过；`object/dev/README.md` 在介绍 `SAFEORBIT_SIMULATOR_ID` 处补一句新变量。摸底读数（执行者读取 T38 最后一次全套测试的结果文件，未独立验证）：152 个用例纯测试用时 592 秒，其中最慢的 12 个排版与字号用例占 76.5%；测试类与文件不一一对应，`RecordsTests.swift` 里另有 `ElderFrontendTests`、`ElderLiveNavigationTests`、`AgentSessionTests` 三个测试类。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)

## 过程记录

- #692｜create｜Claude Code｜{"authority": null, "deps": ["T38"], "id": "T41", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 不设变量时行为不变 | 不设 `SAFEORBIT_ONLY_TESTING`，运行 `sh object/dev/ios-check.sh` | 退出码 0；执行的测试数与改动前全套相同（T38 交付时为 152） |\n| A2 | 筛选生效 | `SAFEORBIT_ONLY_TESTING=SafeOrbitTests/RiskAlertsTests sh object/dev/ios-check.sh`；另以逗号分隔两项再跑一次 | 退出码 0；只执行所列测试，测试数与所列用例数一致；回执记下两种跑法的用时 |\n| A3 | 规则与说明写齐 | 阅读根契约第 4.7 节与 `gate/checks.md` iOS 一节的差异；`grep -rn` 核对“第 25 条”与变量名 | 第 25 条两项齐全、写明把守方式，与用户确认的条文一致；gate 写明变量用法与“读数以全套为准”；其他章节不变 |\n| A4 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T38 已通过；提交时的队列检查 | 仅授权位置；改 `gate/checks.md` 时 T38 已通过；退出码 0 |\n\n验收安排：第 25 条条文先请用户确认；A1–A4 由执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”。最终由用户验收。", "origin": "用户在任务 [T38](../T38/goal.md) 施工后要求落实两条提速做法，并同意先登记、看过方案再批准。T38 的实况（执行者记录，未独立验证）：\n\n- iOS 全套测试每遍约 10 分钟（150 余个用例，其中大量截图与布局用例要在六种屏宽、多档字号下渲染），施工中改了再测，至少跑了 3 遍。\n- App 端要按后端实际定下的接口写，只能等后端交回、执行者审阅提交后才开工；后端约 38 分钟、App 端约 65 分钟，基本串行。\n\n目的：施工中途只跑受影响的测试类，交付前跑一次全套；同时改后端与 App 的任务，先写定接口约定，让两边的子代理同时开工。", "plan": "1. 写账前比对远端；用户批准后，等 T38 通过再领取：`gate/checks.md` 是 T38 本轮的交付文件，T38 通过前不改。\n2. 拟第 25 条条文请用户确认。\n3. 改 `ios-check.sh`、`gate/checks.md` 与根契约。\n4. 跑 A1–A4；写回执交付，同批提交并推送；等用户验收。", "scope": "- 要交付：\n  - `object/dev/ios-check.sh`：新增可选环境变量 `SAFEORBIT_ONLY_TESTING`，值为逗号分隔的测试标识（如 `SafeOrbitTests/RiskAlertsTests`，或细到单个测试方法），逐项转成 xcodebuild 的 `-only-testing:` 参数；不设时与现在完全相同，跑全套。脚本注释写明用法。\n  - `gate/checks.md` 的“iOS 构建与单元测试”一节：补写这个变量；写明任务回执与验收的读数一律以全套为准。\n  - 根契约第 4.7 节新增第 25 条“施工提速”，两项：\n    1. iOS 测试分两档：施工中途只跑受影响的测试类（用上述变量）；交付前按 `gate/checks.md` 跑一次全套，回执与验收读数以全套为准。\n    2. 同时改后端与 App 的任务：施工前由执行者写定接口约定——路径、调用身份、请求与回复示例、推送载荷与本地化键、错误码——经 `task replan` 写进执行计划；后端与 App 的子代理读取状态包里的同一份约定同时开工，各自用替身对照约定写测试；合入后由执行者联调一次。约定须改时同样经 `task replan`。\n\n    把守：靠自觉。条文经用户确认后写入（常设规则变更，见 `charter/AGENTS.md`）。\n- 不包含：修改或删减测试用例；其他检查脚本与提交钩子；T39、T40 的方案（它们补全方案时按新规则写）；模板机制文件；第 4.5、4.6 节。\n- 允许修改的位置：`AGENTS.md`（仅第 4.7 节新增第 25 条）；`object/dev/ios-check.sh`；`gate/checks.md`（仅“iOS 构建与单元测试”一节）。队列记录只经工具维护。", "title": "施工提速：iOS 测试分两档，前后端按接口约定并行"}}
- #693｜revise｜Claude Code｜{"basis": "用户审阅修订稿后确认按它修订：写明测试标识填测试类名而不是文件名；所列每一项都须至少执行一个测试，否则脚本报错，防止拼错时假通过；object/dev/README.md 在介绍 SAFEORBIT_SIMULATOR_ID 处补一句新变量。", "deps": ["T38"], "expect": 692, "id": "T41", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 不设变量时行为不变 | 不设 `SAFEORBIT_ONLY_TESTING`，运行 `sh object/dev/ios-check.sh` | 退出码 0；执行的测试数与改动前全套相同（T38 交付时为 152） |\n| A2 | 筛选生效 | `SAFEORBIT_ONLY_TESTING=SafeOrbitTests/RiskAlertsTests sh object/dev/ios-check.sh`；另以逗号分隔两项再跑一次，其中一项细到单个方法 | 退出码 0；只执行所列测试，测试数与所列用例数一致；回执记下两种跑法的用时 |\n| A3 | 拼错不会假通过 | 只列一个拼错的类名（如 `SafeOrbitTests/RiskAlertTests`）运行一次；一项写对、一项拼错再运行一次 | 两次退出码均非 0，输出指出没有匹配到测试的那一项；回执附原样输出摘录 |\n| A4 | 规则与说明写齐 | 阅读根契约第 4.7 节、`gate/checks.md` iOS 一节与 `object/dev/README.md`“验证”一节的差异；`grep -rn` 核对“第 25 条”与变量名 | 第 25 条两项齐全、写明把守方式，与用户确认的条文一致；gate 写明标识写法（类名而非文件名）、没有匹配到测试即报错、“读数以全套为准”；README 补了一句并指向 gate；其他章节不变 |\n| A5 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T38 已通过；提交时的队列检查 | 仅授权位置；改 `gate/checks.md` 与 `object/dev/README.md` 时 T38 已通过；退出码 0 |\n\n验收安排：第 25 条条文先请用户确认；A1–A5 由执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”。最终由用户验收。", "origin": "用户在任务 [T38](../T38/goal.md) 施工后要求落实两条提速做法，并同意先登记、看过方案再批准。T38 的实况（执行者记录，未独立验证）：\n\n- iOS 全套测试每遍约 10 分钟（150 余个用例，其中大量截图与布局用例要在六种屏宽、多档字号下渲染），施工中改了再测，至少跑了 3 遍。\n- App 端要按后端实际定下的接口写，只能等后端交回、执行者审阅提交后才开工；后端约 38 分钟、App 端约 65 分钟，基本串行。\n\n目的：施工中途只跑受影响的测试类，交付前跑一次全套；同时改后端与 App 的任务，先写定接口约定，让两边的子代理同时开工。\n\n修订（登记后、批准前，用户看过执行者的只读摸底后决定）：补三处——写明测试标识填的是测试类名而不是文件名；所列测试标识没有匹配到测试时脚本报错，防止拼错时假通过；`object/dev/README.md` 在介绍 `SAFEORBIT_SIMULATOR_ID` 处补一句新变量。摸底读数（执行者读取 T38 最后一次全套测试的结果文件，未独立验证）：152 个用例纯测试用时 592 秒，其中最慢的 12 个排版与字号用例占 76.5%；测试类与文件不一一对应，`RecordsTests.swift` 里另有 `ElderFrontendTests`、`ElderLiveNavigationTests`、`AgentSessionTests` 三个测试类。", "plan": "1. 写账前比对远端；用户批准后，等 T38 通过再领取：`gate/checks.md` 与 `object/dev/README.md` 都是 T38 本轮的交付文件，T38 通过前不改。\n2. 拟第 25 条条文请用户确认。\n3. 改 `ios-check.sh`（筛选，以及每项至少执行一个测试的核对）、`gate/checks.md`、`object/dev/README.md` 与根契约。\n4. 跑 A1–A5；写回执交付，同批提交并推送；等用户验收。", "scope": "- 要交付：\n  - `object/dev/ios-check.sh`：\n    - 新增可选环境变量 `SAFEORBIT_ONLY_TESTING`，值为逗号分隔的测试标识，写成 `SafeOrbitTests/<测试类名>` 或细到单个方法 `SafeOrbitTests/<测试类名>/<方法名>`（如 `SafeOrbitTests/RiskAlertsTests`），逐项转成 xcodebuild 的 `-only-testing:` 参数。\n    - 设了变量时，核对所列每一项都至少执行了一个测试；有任何一项没有匹配到测试（如拼错、把文件名当成类名），脚本以非零退出码结束并指出是哪一项，不论 xcodebuild 本身是否报错。\n    - 不设变量时与现在完全相同：仍直接调用 xcodebuild 跑全套，不做上述核对。\n    - 脚本注释写明用法。\n  - `gate/checks.md` 的“iOS 构建与单元测试”一节：补写这个变量——标识的写法，说明填的是测试类名而不是文件名（以 `RecordsTests.swift` 里的几个测试类为例），以及没有匹配到测试时脚本报错；写明任务回执与验收的读数一律以全套为准。\n  - `object/dev/README.md` 的“验证”一节：在介绍 `SAFEORBIT_SIMULATOR_ID` 的那句之后补一句：只跑部分测试类时设 `SAFEORBIT_ONLY_TESTING`，写法与“读数以全套为准”见 `gate/checks.md`。\n  - 根契约第 4.7 节新增第 25 条“施工提速”，两项：\n    1. iOS 测试分两档：施工中途只跑受影响的测试类（用上述变量）；交付前按 `gate/checks.md` 跑一次全套，回执与验收读数以全套为准。\n    2. 同时改后端与 App 的任务：施工前由执行者写定接口约定——路径、调用身份、请求与回复示例、推送载荷与本地化键、错误码——经 `task replan` 写进执行计划；后端与 App 的子代理读取状态包里的同一份约定同时开工，各自用替身对照约定写测试；合入后由执行者联调一次。约定须改时同样经 `task replan`。\n\n    把守：靠自觉。条文经用户确认后写入（常设规则变更，见 `charter/AGENTS.md`）。\n- 不包含：修改或删减测试用例；其他检查脚本与提交钩子；T39、T40 的方案（它们补全方案时按新规则写）；模板机制文件；第 4.5、4.6 节；`object/AGENTS.md` 与 `object/ios/README.md`（只列了脚本命令，不涉及变量）。\n- 允许修改的位置：`AGENTS.md`（仅第 4.7 节新增第 25 条）；`object/dev/ios-check.sh`；`gate/checks.md`（仅“iOS 构建与单元测试”一节）；`object/dev/README.md`（仅“验证”一节补一句）。队列记录只经工具维护。", "title": "施工提速：iOS 测试分两档，前后端按接口约定并行"}}
- #694｜approve｜Claude Code｜{"authority": {"basis": "用户明确指令：修订稿通过，按它修订 T41 并批准，等 T38 通过后再领取施工。", "by": "用户"}, "expect": 693, "id": "T41"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
